-- Adds rough-quantity tracking alongside the existing free-text `amount` field.
-- quantity_estimate: low-friction bucket (little/some/a_lot) captured when the user
-- doesn't enter a precise amount. No 4th "uncertain" value is stored — a null
-- quantity_estimate combined with a null/empty amount is treated as uncertain at
-- read time only.
-- quantity_source: where the quantity value came from, for downstream fallback logic.

create type quantity_estimate as enum ('little', 'some', 'a_lot');
create type quantity_source as enum ('manual_estimate', 'manual_precise', 'barcode');

alter table ingredients add column if not exists quantity_estimate quantity_estimate;
alter table ingredients add column if not exists quantity_source quantity_source;

-- Backfill: rows with an existing precise amount are the closest inferable signal
-- we have (barcode vs. manual-precise is indistinguishable historically, so this is
-- a best guess). Rows without an amount are left null and resolve to "uncertain" via
-- the read-path fallback chain rather than being guessed retroactively.
update ingredients
set quantity_source = 'manual_precise'
where amount is not null and amount != '' and quantity_source is null;
