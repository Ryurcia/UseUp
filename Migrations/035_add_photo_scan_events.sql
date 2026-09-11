-- Telemetry for TieredFoodPhotoScanner: one row per Photo Scan capture, recording which Gemini
-- tier resolved it, tier-1's confidence, and whether/why it escalated to tier 2. Query directly
-- via the Supabase SQL Editor (see the aggregate examples in the implementation plan) — there's no
-- in-app admin UI for this yet.
--
-- user_id defaults to auth.uid() rather than being client-supplied, matching
-- 034_recreate_collections.sql — this session's own RLS investigation found a client-supplied
-- user_id can silently diverge from the request's real authenticated identity.
create table public.photo_scan_events (
  id                    uuid primary key default gen_random_uuid(),
  user_id               uuid not null default auth.uid() references auth.users(id) on delete cascade,
  resolved_tier         text not null check (resolved_tier in ('lite', 'standard')),
  lite_item_count       integer,
  lite_min_confidence   double precision,
  lite_avg_confidence   double precision,
  escalated             boolean not null,
  escalation_reason     text check (escalation_reason in ('empty', 'low_confidence', 'error')),
  final_item_count      integer not null,
  created_at            timestamptz not null default now()
);

create index idx_photo_scan_events_user_date on public.photo_scan_events(user_id, created_at);

alter table public.photo_scan_events enable row level security;

create policy "Users can view own scan events" on public.photo_scan_events
  for select to authenticated using (auth.uid() = user_id);

create policy "Users can insert own scan events" on public.photo_scan_events
  for insert to authenticated with check (auth.uid() = user_id);
