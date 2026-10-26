-- Court Rush only. Existing ttk_* tables, Auth providers and functions are untouched.
create schema if not exists cr_private;
revoke all on schema cr_private from public, anon, authenticated;
grant usage on schema cr_private to service_role;
create table public.cr_accounts (
 user_id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check(username ~ '^[a-z0-9_]{4,20}$'),
 login_alias text not null unique,
 recovery_hash text not null,
 created_at timestamptz not null default now()
);
alter table public.cr_accounts enable row level security;
revoke all on public.cr_accounts from public,anon,authenticated;
grant all on public.cr_accounts to service_role;
create table public.cr_players (
 user_id uuid primary key references public.cr_accounts(user_id) on delete cascade,
 data jsonb not null check(data->>'version'='1'),
 revision integer not null default 1,
 updated_at timestamptz not null default now()
);
alter table public.cr_players enable row level security;
revoke all on public.cr_players from public,anon,authenticated;
grant all on public.cr_players to service_role;
create table public.cr_matches (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.cr_accounts(user_id) on delete cascade,
 stage integer not null check(stage between 1 and 8),
 game_mode text not null default 'duel' check(game_mode in ('duel','team')),
 setup jsonb not null default '{}'::jsonb,
 started_at timestamptz not null default now(),
 finished_at timestamptz,
 result jsonb
);
create index cr_matches_user on public.cr_matches(user_id,started_at desc);
alter table public.cr_matches enable row level security;
revoke all on public.cr_matches from public,anon,authenticated;
grant all on public.cr_matches to service_role;
create table public.cr_rate_limits (
 key_hash text primary key, window_start timestamptz not null, count integer not null
);
create index cr_rate_limits_expiry on public.cr_rate_limits(window_start);
alter table public.cr_rate_limits enable row level security;
revoke all on public.cr_rate_limits from public,anon,authenticated;
grant all on public.cr_rate_limits to service_role;
create or replace function public.cr_rate_limit(p_key text,p_limit integer,p_seconds integer)
returns boolean language plpgsql security invoker set search_path='' as $$
declare n integer;
begin
 delete from public.cr_rate_limits where window_start<now()-interval '2 days';
 insert into public.cr_rate_limits as r values(p_key,now(),1)
 on conflict(key_hash) do update set
 count=case when r.window_start<now()-make_interval(secs=>p_seconds) then 1 else r.count+1 end,
 window_start=case when r.window_start<now()-make_interval(secs=>p_seconds) then now() else r.window_start end
 returning count into n;
 return n<=p_limit;
end $$;
revoke all on function public.cr_rate_limit(text,integer,integer) from public,anon,authenticated;
grant execute on function public.cr_rate_limit(text,integer,integer) to service_role;
-- A private, narrowly scoped privileged helper reads Auth session existence.
create or replace function cr_private.session_exists(p_user uuid,p_session uuid)
returns boolean language sql security definer set search_path='' as $$
 select exists(select 1 from auth.sessions where id=p_session and user_id=p_user and (not_after is null or not_after>now()));
$$;
revoke all on function cr_private.session_exists(uuid,uuid) from public,anon,authenticated;
grant execute on function cr_private.session_exists(uuid,uuid) to service_role;
create or replace function public.cr_session_valid(p_user uuid,p_session uuid)
returns boolean language sql security invoker set search_path='' as $$ select cr_private.session_exists(p_user,p_session); $$;
revoke all on function public.cr_session_valid(uuid,uuid) from public,anon,authenticated;
grant execute on function public.cr_session_valid(uuid,uuid) to service_role;
-- A single transaction commits both the new progression and receipt.
create or replace function public.cr_finish_match(p_user uuid,p_match uuid,p_revision integer,p_data jsonb,p_result jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare m public.cr_matches; v public.cr_players;
begin
 select * into m from public.cr_matches where id=p_match and user_id=p_user for update;
 if not found then raise exception 'match_not_found'; end if;
 select * into v from public.cr_players where user_id=p_user for update;
 if m.finished_at is not null then return jsonb_build_object('player',v.data,'reward',m.result); end if;
 if v.revision<>p_revision then raise exception 'stale_profile' using errcode='40001'; end if;
 update public.cr_players set data=p_data,revision=revision+1,updated_at=now() where user_id=p_user;
 update public.cr_matches set finished_at=now(),result=p_result where id=p_match;
 return jsonb_build_object('player',p_data,'reward',p_result);
end $$;
revoke all on function public.cr_finish_match(uuid,uuid,integer,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.cr_finish_match(uuid,uuid,integer,jsonb,jsonb) to service_role;
