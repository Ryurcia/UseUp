create extension if not exists pg_cron with schema extensions;

alter table public.ingredients add column if not exists wasted_recorded_at timestamptz;

-- Daily sweep: any ingredient whose expiration_date has passed and hasn't yet been recorded
-- gets a 'wasted' pantry_events row (so it counts toward the Stats screen's $ wasted/binned
-- totals even if the user never manually deletes it), then gets stamped so it's never
-- double-counted — including if the user later does delete it (PantryStore.deleteIngredient
-- skips its own wasted-event write when wasted_recorded_at is already set).
-- occurred_at backdates to the actual expiration date (not the cron run time) so the item lands
-- in the correct week/month bucket on the Stats screen even if the sweep catches it days later.
create or replace function public.record_expired_ingredients_as_wasted()
returns void as $$
begin
  insert into public.pantry_events (user_id, ingredient_id, ingredient_name, ingredient_key, category, outcome, cost_value, occurred_at)
  select user_id, id, name, lower(trim(name)), category, 'wasted', estimated_total_cost, expiration_date::timestamptz
  from public.ingredients
  where expiration_date < current_date
    and wasted_recorded_at is null;

  update public.ingredients
  set wasted_recorded_at = now()
  where expiration_date < current_date
    and wasted_recorded_at is null;
end;
$$ language plpgsql security definer;

select cron.schedule(
  'record-expired-ingredients-as-wasted',
  '30 0 * * *', -- daily at 00:30 UTC
  $$ select public.record_expired_ingredients_as_wasted(); $$
);
