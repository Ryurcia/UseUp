-- Pinterest-style user-created "Collections" for organizing saved recipes, replacing the
-- single-select saved_recipes.category tag added in 011_add_saved_recipe_category.sql.
-- A saved recipe can belong to zero or more collections.

create table public.collections (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  created_at  timestamptz not null default now()
);

create index idx_collections_user on public.collections(user_id);

alter table public.collections enable row level security;

create policy "Users can view own collections"
  on public.collections for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Users can create own collections"
  on public.collections for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can delete own collections"
  on public.collections for delete
  to authenticated
  using (auth.uid() = user_id);

-- collection_recipes: M:N join between collections and recipes. user_id is denormalized onto
-- this join table (same pattern as saved_recipes / recipe_ratings / blocked_users) so RLS can
-- do a direct auth.uid() = user_id check instead of a subquery-per-row join through collections
-- on every select.
create table public.collection_recipes (
  collection_id  uuid not null references public.collections(id) on delete cascade,
  recipe_id      uuid not null references public.recipes(id) on delete cascade,
  user_id        uuid not null references auth.users(id) on delete cascade,
  created_at     timestamptz not null default now(),
  primary key (collection_id, recipe_id)
);

create index idx_collection_recipes_collection on public.collection_recipes(collection_id);
create index idx_collection_recipes_recipe on public.collection_recipes(recipe_id);

alter table public.collection_recipes enable row level security;

create policy "Users can view own collection recipes"
  on public.collection_recipes for select
  to authenticated
  using (auth.uid() = user_id);

-- Requires BOTH user_id = auth.uid() AND that the target collection actually belongs to
-- auth.uid(), so a caller can't forge collection_id into someone else's collection while
-- claiming user_id = themselves.
create policy "Users can add recipes to own collections"
  on public.collection_recipes for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.collections
      where id = collection_id and user_id = auth.uid()
    )
  );

create policy "Users can remove recipes from own collections"
  on public.collection_recipes for delete
  to authenticated
  using (auth.uid() = user_id);
