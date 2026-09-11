-- Pantry event ledger.
--
-- One row per bought / used / wasted pantry event, snapshotting the item's cost + category at
-- the moment it happened. Backs the Stats screen (spend & waste over time, waste by category,
-- repeat offenders). Written fire-and-forget from PantryStore on add / delete; insert-only,
-- never updated. No backfill — history accrues going forward.
--
-- `ingredient_key` = lower(trim(name)), matching ingredient_history / ingredient_price_history,
-- so "expired N of M times bought" is `count(outcome='wasted') / count(outcome='bought')` per key.

create table public.pantry_events (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users(id) on delete cascade,
  ingredient_id   uuid,
  ingredient_name text not null,
  ingredient_key  text not null,
  category        ingredient_category not null default 'other',
  outcome         text not null check (outcome in ('bought', 'used', 'wasted')),
  cost_value      numeric(10,2),
  occurred_at     timestamptz not null default now()
);

create index idx_pantry_events_user_time on public.pantry_events (user_id, occurred_at);
create index idx_pantry_events_user_key  on public.pantry_events (user_id, ingredient_key);

alter table public.pantry_events enable row level security;

create policy "Users can view own pantry events"
  on public.pantry_events for select
  using (auth.uid() = user_id);

create policy "Users can insert own pantry events"
  on public.pantry_events for insert
  with check (auth.uid() = user_id);
