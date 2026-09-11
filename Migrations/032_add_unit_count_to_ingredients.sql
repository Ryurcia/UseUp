-- "Quantity owned" — how many of the logged unit size the user has (e.g. 5 cans of 227g each).
-- `amount` keeps its existing meaning (per-unit size); total on-hand is derived client-side as
-- amount x unit_count (see Ingredient.totalAmount), not stored as a separate computed column.
alter table public.ingredients add column unit_count integer not null default 1;
