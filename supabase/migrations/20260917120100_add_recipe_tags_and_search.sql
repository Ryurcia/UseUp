-- Tags dimension + full-text search for recipes, replacing ILIKE title/summary search.

-- Cleanup from an earlier failed attempt at this migration (generated-column approach,
-- superseded by the trigger-based one below) — drop if it made it onto this database.
drop function if exists public.immutable_to_tsvector(text);

alter table public.recipes
  add column if not exists tags text[] not null default '{}';

create index if not exists idx_recipes_tags
  on public.recipes using gin (tags);

-- search_vector as a GENERATED ALWAYS STORED column kept failing Postgres's "generation
-- expression is not immutable" check even behind an explicitly-immutable wrapper function
-- (casting a text literal to regconfig, which to_tsvector('english', ...) needs, is only
-- STABLE — it depends on search_path). A trigger-maintained plain column sidesteps that
-- restriction entirely and is the classic, pre-generated-column way to do this in Postgres.
alter table public.recipes
  add column if not exists search_vector tsvector;

create or replace function public.recipes_search_vector_update()
returns trigger
language plpgsql
as $$
begin
  new.search_vector := to_tsvector('english',
    coalesce(new.title, '') || ' ' ||
    coalesce(new.summary, '') || ' ' ||
    coalesce(new.cuisine::text, '') || ' ' ||
    coalesce(array_to_string(new.tags, ' '), '') || ' ' ||
    coalesce(array_to_string(new.dietary_restrictions, ' '), '')
  );
  return new;
end;
$$;

drop trigger if exists recipes_search_vector_trigger on public.recipes;
create trigger recipes_search_vector_trigger
  before insert or update on public.recipes
  for each row execute function public.recipes_search_vector_update();

-- Backfill existing rows — the trigger only fires on future inserts/updates.
update public.recipes
set search_vector = to_tsvector('english',
  coalesce(title, '') || ' ' ||
  coalesce(summary, '') || ' ' ||
  coalesce(cuisine::text, '') || ' ' ||
  coalesce(array_to_string(tags, ' '), '') || ' ' ||
  coalesce(array_to_string(dietary_restrictions, ' '), '')
)
where search_vector is null;

create index if not exists idx_recipes_search_vector
  on public.recipes using gin (search_vector);
