-- Applied to the existing shared project through apply_migration on 2026-10-26.
-- Court Rush only; legacy matches keep duel semantics and existing RLS.
alter table public.cr_matches
  add column game_mode text not null default 'duel'
  check (game_mode in ('duel','team'));
alter table public.cr_matches
  add column setup jsonb not null default '{}'::jsonb;
