-- Additive online career/Elo v2. Apply after online-schema.sql; no shared Auth/ttk_* changes.
create table public.cr_online_ratings (
 user_id uuid primary key references public.cr_accounts(user_id) on delete cascade,
 rating integer not null default 1000 check(rating between 0 and 100000),
 wins integer not null default 0 check(wins>=0),
 losses integer not null default 0 check(losses>=0),
 draws integer not null default 0 check(draws>=0),
 games integer not null default 0 check(games=wins+losses+draws),
 updated_at timestamptz not null default now()
);
create index cr_online_ratings_board on public.cr_online_ratings(rating desc,wins desc,updated_at);
alter table public.cr_online_ratings enable row level security;
revoke all on public.cr_online_ratings from public,anon,authenticated,service_role;
grant select,insert,update,delete on public.cr_online_ratings to service_role;
alter table public.cr_online_matches add column ranked boolean not null default true;

create function public.cr_online_register_ranked(p_server text,p_epoch uuid,p_match uuid,p_tickets uuid[],p_ranked boolean)
returns boolean language plpgsql security invoker set search_path='' as $$
begin
 perform public.cr_online_register(p_server,p_epoch,p_match,p_tickets);
 if (select count(*) from public.cr_online_participants where match_id=p_match and profile->>'rulesVersion'='duel-career-v2' and jsonb_typeof(profile->'athlete')='object')<>2 then
  raise exception 'ranked athlete missing' using errcode='42501';
 end if;
 update public.cr_online_matches set rules_version='duel-career-v2',ranked=p_ranked
 where id=p_match and server_id=p_server and epoch=p_epoch and state='active';
 return true;
end $$;

create or replace function public.cr_online_finish(p_server text,p_epoch uuid,p_match uuid,p_result jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
declare
 m public.cr_online_matches; users uuid[]; r0 public.cr_online_ratings; r1 public.cr_online_ratings;
 reason text; winner integer; s0 integer; s1 integer; remaining numeric;
 outcome numeric; expected numeric; change0 integer; before0 integer; before1 integer;
 v_result jsonb; rankings jsonb;
begin
 -- Boot cannot change the epoch while a result is being committed.
 perform 1 from public.cr_online_servers where id=p_server and enabled and epoch=p_epoch for share;
 if not found then raise exception 'invalid server epoch' using errcode='42501'; end if;
 select array_agg(user_id order by slot) into users from public.cr_online_participants where match_id=p_match;
 -- Align account lock order with admission and account deletion.
 perform 1 from public.cr_accounts where user_id=any(users) order by user_id for key share;
 select * into m from public.cr_online_matches where id=p_match and server_id=p_server and epoch=p_epoch for update;
 if not found then raise exception 'match not found' using errcode='42501'; end if;
 if m.state<>'active' then return m.result; end if;
 reason=p_result->>'reason'; winner=(p_result->>'winner')::integer;
 if reason is null or reason not in ('score','draw','forfeit','aborted','cancelled') or winner not in (0,1)
 or jsonb_typeof(p_result->'score') is distinct from 'array' or jsonb_array_length(p_result->'score')<>2 then raise exception 'invalid result'; end if;
 if jsonb_typeof(p_result->'seconds') is distinct from 'number'
 or jsonb_typeof(p_result->'score'->0) is distinct from 'number' or jsonb_typeof(p_result->'score'->1) is distinct from 'number' then raise exception 'invalid numeric result'; end if;
 s0=(p_result->'score'->>0)::integer; s1=(p_result->'score'->>1)::integer; remaining=(p_result->>'seconds')::numeric;
 if s0<0 or s0>13 or s1<0 or s1>13 or remaining<0 or remaining>90
 or (p_result->'score'->>0)::numeric<>s0 or (p_result->'score'->>1)::numeric<>s1 then raise exception 'invalid score'; end if;
 if (reason='score' and (winner is null or s0=s1 or winner<>case when s0>s1 then 0 else 1 end))
 or (reason='draw' and (winner is not null or s0<>s1 or remaining<>0))
 or (reason='forfeit' and winner is null)
 or (reason in ('aborted','cancelled') and winner is not null) then raise exception 'inconsistent winner'; end if;
 v_result=jsonb_build_object('reason',reason,'winner',winner,'score',jsonb_build_array(s0,s1),'seconds',remaining);
 if m.rules_version='duel-career-v2' then
  v_result=v_result||jsonb_build_object('ranked',false);
  if m.ranked and reason in ('score','draw','forfeit') and cardinality(users)=2 then
   insert into public.cr_online_ratings(user_id) select unnest(users) on conflict(user_id) do nothing;
   perform 1 from public.cr_online_ratings where user_id=any(users) order by user_id for update;
   select * into r0 from public.cr_online_ratings where user_id=users[1];
   select * into r1 from public.cr_online_ratings where user_id=users[2];
   before0=r0.rating;before1=r1.rating;
   outcome=case when winner is null then .5 when winner=0 then 1 else 0 end;
   expected=1/(1+power(10::numeric,greatest(-4000,least(4000,before1-before0))::numeric/400));
   change0=round(32*(outcome-expected));
   update public.cr_online_ratings set rating=greatest(0,least(100000,before0+change0)),
    wins=wins+case when winner=0 then 1 else 0 end,losses=losses+case when winner=1 then 1 else 0 end,
    draws=draws+case when winner is null then 1 else 0 end,games=games+1,updated_at=now() where user_id=users[1] returning * into r0;
   update public.cr_online_ratings set rating=greatest(0,least(100000,before1-change0)),
    wins=wins+case when winner=1 then 1 else 0 end,losses=losses+case when winner=0 then 1 else 0 end,
    draws=draws+case when winner is null then 1 else 0 end,games=games+1,updated_at=now() where user_id=users[2] returning * into r1;
   rankings=jsonb_build_array(
    jsonb_build_object('slot',0,'before',before0,'rating',r0.rating,'delta',r0.rating-before0,'wins',r0.wins,'losses',r0.losses,'draws',r0.draws,'games',r0.games),
    jsonb_build_object('slot',1,'before',before1,'rating',r1.rating,'delta',r1.rating-before1,'wins',r1.wins,'losses',r1.losses,'draws',r1.draws,'games',r1.games));
   v_result=v_result||jsonb_build_object('ranked',true,'rankings',rankings);
  end if;
 end if;
 update public.cr_online_matches set state=case when reason in ('aborted','cancelled') then 'aborted' else 'ended' end,finished_at=now(),result=v_result where id=p_match;
 return v_result;
end $$;

create function public.cr_online_ranking(p_user uuid)
returns jsonb language sql stable security invoker set search_path='' as $$
 with mine as (
  select r.rating,r.wins,r.losses,r.draws,r.games,
   (case when r.games>0 then 1+(select count(*) from public.cr_online_ratings x where x.games>0 and x.rating>r.rating) else null end) as rank
  from public.cr_online_ratings r where r.user_id=p_user
 ), board as (
  select rank() over(order by r.rating desc) as rank,r.rating,r.wins,r.losses,r.draws,r.games,
   p.data->>'nickname' as nickname,p.data->>'role' as role,r.user_id=p_user as self
  from public.cr_online_ratings r join public.cr_players p on p.user_id=r.user_id
  where r.games>0 order by r.rating desc,r.wins desc,r.updated_at,r.user_id limit 50
 )
 select jsonb_build_object('rulesVersion','duel-career-v2','initial',1000,'k',32,
  'mine',coalesce((select to_jsonb(mine) from mine),'{"rating":1000,"wins":0,"losses":0,"draws":0,"games":0,"rank":null}'::jsonb),
  'players',coalesce((select jsonb_agg(to_jsonb(board)) from board),'[]'::jsonb));
$$;
revoke all on function public.cr_online_register_ranked(text,uuid,uuid,uuid[],boolean),public.cr_online_finish(text,uuid,uuid,jsonb),public.cr_online_ranking(uuid) from public,anon,authenticated;
grant execute on function public.cr_online_register_ranked(text,uuid,uuid,uuid[],boolean),public.cr_online_finish(text,uuid,uuid,jsonb),public.cr_online_ranking(uuid) to service_role;
