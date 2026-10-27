-- Additive Court Rush online schema. No shared Auth or ttk_* changes.
create table public.cr_online_servers (
 id text primary key check(id ~ '^[a-z0-9-]{3,64}$'),
 key_hash text not null check(key_hash ~ '^[a-f0-9]{64}$'),
 enabled boolean not null default false,
 epoch uuid, heartbeat_at timestamptz
);
create table public.cr_online_tickets (
 id uuid primary key default gen_random_uuid(),
 ticket_hash text not null unique check(ticket_hash ~ '^[a-f0-9]{64}$'),
 server_id text not null references public.cr_online_servers(id),
 user_id uuid not null references public.cr_accounts(user_id) on delete cascade,
 session_id uuid not null,
 profile jsonb not null,
 expires_at timestamptz not null default now()+interval '60 seconds',
 created_at timestamptz not null default now(),
 consumed_at timestamptz, consumed_epoch uuid, redeem_request uuid
);
create index cr_online_tickets_user on public.cr_online_tickets(user_id,created_at desc);
create index cr_online_tickets_expiry on public.cr_online_tickets(expires_at);
create table public.cr_online_matches (
 id uuid primary key,
 server_id text not null references public.cr_online_servers(id),
 epoch uuid not null,
 mode text not null default 'duel' check(mode='duel'),
 rules_version text not null default 'duel-standard-v1',
 state text not null default 'active' check(state in ('active','ended','aborted')),
 started_at timestamptz not null default now(),
 finished_at timestamptz,
 result jsonb
);
create index cr_online_matches_server on public.cr_online_matches(server_id,state);
create table public.cr_online_participants (
 match_id uuid not null references public.cr_online_matches(id) on delete cascade,
 user_id uuid not null references public.cr_accounts(user_id) on delete cascade,
 ticket_id uuid references public.cr_online_tickets(id) on delete set null,
 slot smallint not null check(slot in (0,1)),
 team smallint not null check(team=slot),
 profile jsonb not null,
 primary key(match_id,slot), unique(match_id,user_id)
);
create index cr_online_participants_user on public.cr_online_participants(user_id,match_id);

alter table public.cr_online_servers enable row level security;
alter table public.cr_online_tickets enable row level security;
alter table public.cr_online_matches enable row level security;
alter table public.cr_online_participants enable row level security;
revoke all on public.cr_online_servers,public.cr_online_tickets,public.cr_online_matches,public.cr_online_participants from public,anon,authenticated,service_role;
grant select,insert,update,delete on public.cr_online_servers,public.cr_online_tickets,public.cr_online_matches,public.cr_online_participants to service_role;

create function public.cr_online_boot(p_server text,p_epoch uuid)
returns boolean language plpgsql security invoker set search_path='' as $$
begin
 perform 1 from public.cr_online_servers where id=p_server and enabled for update;
 if not found then raise exception 'online server unavailable' using errcode='42501'; end if;
 update public.cr_online_matches set state='aborted',finished_at=now(),result='{"reason":"server_restart","winner":null}'::jsonb
 where server_id=p_server and state='active' and epoch<>p_epoch;
 update public.cr_online_servers set epoch=p_epoch,heartbeat_at=now() where id=p_server;
 delete from public.cr_online_matches where finished_at<now()-interval '30 days';
 delete from public.cr_online_tickets where (consumed_at is null and expires_at<now()-interval '1 day') or created_at<now()-interval '30 days';
 return true;
end $$;

create function public.cr_online_redeem(p_server text,p_epoch uuid,p_hash text,p_request uuid)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare t public.cr_online_tickets;
begin
 perform 1 from public.cr_online_servers where id=p_server and enabled and epoch=p_epoch;
 if not found then raise exception 'invalid server epoch' using errcode='42501'; end if;
 select * into t from public.cr_online_tickets where ticket_hash=p_hash and server_id=p_server for update;
 if not found or not public.cr_session_valid(t.user_id,t.session_id) then raise exception 'invalid ticket' using errcode='42501'; end if;
 if t.consumed_at is not null then
  if t.consumed_epoch<>p_epoch or t.redeem_request<>p_request then raise exception 'ticket already used' using errcode='42501'; end if;
 elsif t.expires_at<=now() then raise exception 'expired ticket' using errcode='42501';
 else
  update public.cr_online_tickets set consumed_at=now(),consumed_epoch=p_epoch,redeem_request=p_request where id=t.id;
 end if;
 return t.profile || jsonb_build_object('id',t.user_id,'ticketId',t.id);
end $$;

create function public.cr_online_register(p_server text,p_epoch uuid,p_match uuid,p_tickets uuid[])
returns boolean language plpgsql security invoker set search_path='' as $$
declare valid_count integer; user_count integer; prior public.cr_online_matches;
begin
 perform 1 from public.cr_online_servers where id=p_server and enabled and epoch=p_epoch;
 if not found then raise exception 'invalid server epoch' using errcode='42501'; end if;
 if cardinality(p_tickets)<>2 or p_tickets[1]=p_tickets[2] then raise exception 'invalid roster'; end if;
 select * into prior from public.cr_online_matches where id=p_match;
 if found then
  if prior.server_id<>p_server or prior.epoch<>p_epoch then raise exception 'match ownership' using errcode='42501'; end if;
  return true;
 end if;
 perform 1 from public.cr_accounts a where a.user_id in (select t.user_id from public.cr_online_tickets t where t.id=any(p_tickets)) order by a.user_id for update;
 select count(*),count(distinct user_id) into valid_count,user_count from public.cr_online_tickets
 where id=any(p_tickets) and server_id=p_server and consumed_epoch=p_epoch and consumed_at is not null and public.cr_session_valid(user_id,session_id);
 if valid_count<>2 or user_count<>2 then raise exception 'invalid participants' using errcode='42501'; end if;
 if exists(select 1 from public.cr_online_participants p join public.cr_online_matches m on m.id=p.match_id
  where m.state='active' and p.user_id in(select user_id from public.cr_online_tickets where id=any(p_tickets))) then
  raise exception 'already playing' using errcode='23505';
 end if;
 insert into public.cr_online_matches(id,server_id,epoch) values(p_match,p_server,p_epoch);
 insert into public.cr_online_participants(match_id,user_id,ticket_id,slot,team,profile)
 select p_match,t.user_id,t.id,(u.ordinality-1)::smallint,(u.ordinality-1)::smallint,t.profile
 from unnest(p_tickets) with ordinality u(id,ordinality) join public.cr_online_tickets t on t.id=u.id;
 return true;
end $$;

create function public.cr_online_finish(p_server text,p_epoch uuid,p_match uuid,p_result jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare m public.cr_online_matches;
begin
 perform 1 from public.cr_online_servers where id=p_server and enabled and epoch=p_epoch;
 if not found then raise exception 'invalid server epoch' using errcode='42501'; end if;
 select * into m from public.cr_online_matches where id=p_match and server_id=p_server and epoch=p_epoch for update;
 if not found then raise exception 'match not found' using errcode='42501'; end if;
 if m.state<>'active' then return m.result; end if;
 if p_result->>'reason' not in ('score','draw','forfeit','aborted','cancelled') then raise exception 'invalid result'; end if;
 update public.cr_online_matches set state=case when p_result->>'reason' in ('aborted','cancelled') then 'aborted' else 'ended' end,
 finished_at=now(),result=p_result where id=p_match;
 return p_result;
end $$;

revoke all on function public.cr_online_boot(text,uuid),public.cr_online_redeem(text,uuid,text,uuid),public.cr_online_register(text,uuid,uuid,uuid[]),public.cr_online_finish(text,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.cr_online_boot(text,uuid),public.cr_online_redeem(text,uuid,text,uuid),public.cr_online_register(text,uuid,uuid,uuid[]),public.cr_online_finish(text,uuid,uuid,jsonb) to service_role;
