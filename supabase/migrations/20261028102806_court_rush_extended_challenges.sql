-- Exact timestamp returned by remote apply_migration; no Supabase CLI is installed.
-- Existing cr_* receipts only. No player rows, ttk_* objects, RLS or Auth changes.
alter table public.cr_matches drop constraint cr_matches_stage_check;
alter table public.cr_matches add constraint cr_matches_stage_check check (stage between 1 and 24);
alter table public.cr_matches drop constraint cr_matches_game_mode_check;
alter table public.cr_matches add constraint cr_matches_game_mode_check check (game_mode in ('duel','team','challenge'));
