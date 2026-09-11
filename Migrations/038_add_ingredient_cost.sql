-- Ingredient cost estimation.
--
-- ingredient_price_history: one row per (user, ingredient_key), holding a price the
-- user has *confirmed* by correcting an estimate. `ingredient_key` reuses the same
-- normalization as ingredient_history — lower(trim(name)). The resolve-ingredient-cost
-- edge function reads this table (tier 1 of the cost cascade); only the client writes
-- to it, on a user correction, always with source = 'personal'. The `source` CHECK and
-- `barcode` column are permissive for a future tier that caches crowdsourced OFF prices.
--
-- ingredients.* cost columns: the estimate resolved at log time, kept on the item so a
-- later quantity edit can re-derive the total locally and future spend/waste features
-- have a per-item number to work with. All nullable — historical rows and failed
-- resolutions have none.

create table public.ingredient_price_history (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  ingredient_key text not null,
  unit_price numeric(10,2) not null,
  unit text not null,
  source text not null check (source in ('personal', 'openfoodfacts', 'estimate')),
  barcode text,
  last_updated timestamptz not null default now(),
  unique (user_id, ingredient_key)
);

create index idx_ingredient_price_history_lookup
  on public.ingredient_price_history (user_id, ingredient_key);

alter table public.ingredient_price_history enable row level security;

create policy "Users can view own price history"
  on public.ingredient_price_history for select
  using (auth.uid() = user_id);

create policy "Users can insert own price history"
  on public.ingredient_price_history for insert
  with check (auth.uid() = user_id);

create policy "Users can update own price history"
  on public.ingredient_price_history for update
  using (auth.uid() = user_id);

alter table public.ingredients add column estimated_unit_cost numeric(10,2);
alter table public.ingredients add column estimated_total_cost numeric(10,2);
alter table public.ingredients add column cost_unit text;
alter table public.ingredients add column cost_source text
  check (cost_source is null or cost_source in ('personal', 'openfoodfacts', 'estimate'));
