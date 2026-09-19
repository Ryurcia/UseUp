-- Cuisine recipe counts across the whole shared feed, used by the Recipes tab to decide
-- which cuisine sections to show without fetching/scanning the full recipes table
-- client-side. PostgREST has no native GROUP BY, so this is exposed as an RPC.
create or replace function public.get_cuisine_counts()
returns table (cuisine cuisine_type, cnt bigint)
language sql
stable
security definer
set search_path = public
as $$
  select cuisine, count(*) as cnt
  from public.recipes
  where is_user_shared = true
  group by cuisine;
$$;

grant execute on function public.get_cuisine_counts() to authenticated;
