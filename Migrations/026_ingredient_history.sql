-- Per-user distinct ingredient name history, for name-autocomplete suggestions.
-- One row per (user, lower(name)), upserted via a trigger whenever an ingredient
-- is added — survives the live `ingredients` row later being deleted (used up /
-- removed), which is exactly when suggesting a recurring ingredient is useful.

create table public.ingredient_history (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  name          text not null,
  category      ingredient_category not null default 'other',
  use_count     int not null default 1,
  last_used_at  timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create unique index idx_ingredient_history_user_name_unique
  on public.ingredient_history (user_id, lower(name));

create index idx_ingredient_history_user_recency
  on public.ingredient_history (user_id, last_used_at desc);

alter table public.ingredient_history enable row level security;

create policy "Users can view own ingredient history"
  on public.ingredient_history for select
  using (auth.uid() = user_id);

-- Kept in sync via trigger only (security definer, same pattern as
-- handle_new_user() in 001_initial_schema.sql) — no direct insert/update
-- policy needed for authenticated clients.
create or replace function record_ingredient_history()
returns trigger as $$
begin
  insert into public.ingredient_history (user_id, name, category, use_count, last_used_at)
  values (new.user_id, new.name, new.category, 1, now())
  on conflict (user_id, lower(name))
  do update set
    use_count    = public.ingredient_history.use_count + 1,
    last_used_at = now(),
    category     = excluded.category;
  return new;
end;
$$ language plpgsql security definer;

create trigger ingredients_record_history
  after insert on public.ingredients
  for each row execute function record_ingredient_history();
