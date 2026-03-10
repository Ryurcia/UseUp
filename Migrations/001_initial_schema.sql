-- ============================================================
-- UseUp — Initial Schema Migration
-- Run this in the Supabase SQL Editor (or via supabase db push)
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. ENUMS
-- ────────────────────────────────────────────────────────────

create type ingredient_category as enum (
  'proteins', 'vegetables', 'carbs', 'dairy', 'fruits', 'condiments', 'other'
);

create type storage_location as enum (
  'pantry', 'fridge', 'freezer'
);

create type cuisine_type as enum (
  'american', 'asian', 'chinese', 'filipino', 'french', 'greek',
  'indian', 'italian', 'japanese', 'korean', 'mediterranean',
  'mexican', 'middleEastern', 'thai', 'other'
);

create type recipe_ingredient_kind as enum (
  'used', 'missing'
);

-- ────────────────────────────────────────────────────────────
-- 2. HELPER FUNCTIONS
-- ────────────────────────────────────────────────────────────

-- Auto-set updated_at on every UPDATE
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Auto-create a profiles row when a new user signs up
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id)
  values (new.id);
  return new;
end;
$$ language plpgsql security definer;

-- Recompute avg_rating & rating_count on recipes
create or replace function update_recipe_avg_rating()
returns trigger as $$
declare
  target_recipe_id uuid;
begin
  target_recipe_id := coalesce(new.recipe_id, old.recipe_id);

  update public.recipes
  set avg_rating   = coalesce(sub.avg, 0),
      rating_count = coalesce(sub.cnt, 0)
  from (
    select avg(rating)::numeric(3,2) as avg,
           count(*)::int             as cnt
    from public.recipe_ratings
    where recipe_id = target_recipe_id
  ) sub
  where id = target_recipe_id;

  return null;
end;
$$ language plpgsql security definer;

-- ────────────────────────────────────────────────────────────
-- 3. TABLES
-- ────────────────────────────────────────────────────────────

-- 3a. profiles (1:1 with auth.users)
create table public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  nickname     text,
  display_name text,
  avatar_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function set_updated_at();

-- Wire up auto-create on signup
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- 3b. ingredients (pantry items)
create table public.ingredients (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  name            text not null,
  amount          text,
  category        ingredient_category not null default 'other',
  location        storage_location not null,
  expiration_date date,
  logged_at       timestamptz not null default now(),
  notes           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index idx_ingredients_user on public.ingredients(user_id);

create trigger ingredients_updated_at
  before update on public.ingredients
  for each row execute function set_updated_at();

-- 3c. recipes
create table public.recipes (
  id              uuid primary key default gen_random_uuid(),
  created_by      uuid not null references auth.users(id) on delete cascade,
  title           text not null,
  summary         text not null default '',
  time_minutes    int not null default 0,
  servings        int not null default 1,
  steps           text[] not null default '{}',
  cuisine         cuisine_type not null default 'other',
  is_user_shared  boolean not null default false,
  image_path      text,
  -- macros stored as columns for queryability
  calories        int not null default 0,
  protein_g       int not null default 0,
  carbs_g         int not null default 0,
  fat_g           int not null default 0,
  -- denormalized rating aggregates (kept in sync via trigger)
  avg_rating      numeric(3,2) not null default 0,
  rating_count    int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index idx_recipes_created_by on public.recipes(created_by);
create index idx_recipes_shared on public.recipes(is_user_shared) where is_user_shared = true;

create trigger recipes_updated_at
  before update on public.recipes
  for each row execute function set_updated_at();

-- 3d. recipe_ingredients
create table public.recipe_ingredients (
  id          uuid primary key default gen_random_uuid(),
  recipe_id   uuid not null references public.recipes(id) on delete cascade,
  kind        recipe_ingredient_kind not null,
  name        text not null,
  quantity    text not null default '',
  created_at  timestamptz not null default now()
);

create index idx_recipe_ingredients_recipe on public.recipe_ingredients(recipe_id);

-- 3e. source_links
create table public.source_links (
  id         uuid primary key default gen_random_uuid(),
  recipe_id  uuid not null references public.recipes(id) on delete cascade,
  title      text not null,
  url        text not null,
  created_at timestamptz not null default now()
);

create index idx_source_links_recipe on public.source_links(recipe_id);

-- 3f. saved_recipes (M:N bookmark join)
create table public.saved_recipes (
  user_id    uuid not null references auth.users(id) on delete cascade,
  recipe_id  uuid not null references public.recipes(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, recipe_id)
);

-- 3g. recipe_ratings
create table public.recipe_ratings (
  user_id    uuid not null references auth.users(id) on delete cascade,
  recipe_id  uuid not null references public.recipes(id) on delete cascade,
  rating     numeric(3,2) not null check (rating >= 0 and rating <= 5),
  review     text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, recipe_id)
);

create trigger recipe_ratings_updated_at
  before update on public.recipe_ratings
  for each row execute function set_updated_at();

-- Trigger to keep avg_rating/rating_count in sync
create trigger recipe_ratings_sync
  after insert or update or delete on public.recipe_ratings
  for each row execute function update_recipe_avg_rating();

-- ────────────────────────────────────────────────────────────
-- 4. ROW LEVEL SECURITY
-- ────────────────────────────────────────────────────────────

-- Enable RLS on all tables
alter table public.profiles          enable row level security;
alter table public.ingredients       enable row level security;
alter table public.recipes           enable row level security;
alter table public.recipe_ingredients enable row level security;
alter table public.source_links      enable row level security;
alter table public.saved_recipes     enable row level security;
alter table public.recipe_ratings    enable row level security;

-- profiles: users can read/update only their own row
create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- ingredients: full CRUD on own rows only
create policy "Users can view own ingredients"
  on public.ingredients for select
  using (auth.uid() = user_id);

create policy "Users can insert own ingredients"
  on public.ingredients for insert
  with check (auth.uid() = user_id);

create policy "Users can update own ingredients"
  on public.ingredients for update
  using (auth.uid() = user_id);

create policy "Users can delete own ingredients"
  on public.ingredients for delete
  using (auth.uid() = user_id);

-- recipes: own recipes + shared recipes readable by all authenticated users
create policy "Users can view own recipes"
  on public.recipes for select
  using (auth.uid() = created_by);

create policy "Users can view shared recipes"
  on public.recipes for select
  using (is_user_shared = true);

create policy "Users can insert own recipes"
  on public.recipes for insert
  with check (auth.uid() = created_by);

create policy "Users can update own recipes"
  on public.recipes for update
  using (auth.uid() = created_by);

create policy "Users can delete own recipes"
  on public.recipes for delete
  using (auth.uid() = created_by);

-- recipe_ingredients: follow parent recipe visibility
create policy "Users can view own recipe ingredients"
  on public.recipe_ingredients for select
  using (
    exists (
      select 1 from public.recipes
      where id = recipe_id and (created_by = auth.uid() or is_user_shared = true)
    )
  );

create policy "Users can insert own recipe ingredients"
  on public.recipe_ingredients for insert
  with check (
    exists (
      select 1 from public.recipes
      where id = recipe_id and created_by = auth.uid()
    )
  );

create policy "Users can update own recipe ingredients"
  on public.recipe_ingredients for update
  using (
    exists (
      select 1 from public.recipes
      where id = recipe_id and created_by = auth.uid()
    )
  );

create policy "Users can delete own recipe ingredients"
  on public.recipe_ingredients for delete
  using (
    exists (
      select 1 from public.recipes
      where id = recipe_id and created_by = auth.uid()
    )
  );

-- source_links: follow parent recipe visibility
create policy "Users can view source links"
  on public.source_links for select
  using (
    exists (
      select 1 from public.recipes
      where id = recipe_id and (created_by = auth.uid() or is_user_shared = true)
    )
  );

create policy "Users can insert own source links"
  on public.source_links for insert
  with check (
    exists (
      select 1 from public.recipes
      where id = recipe_id and created_by = auth.uid()
    )
  );

create policy "Users can update own source links"
  on public.source_links for update
  using (
    exists (
      select 1 from public.recipes
      where id = recipe_id and created_by = auth.uid()
    )
  );

create policy "Users can delete own source links"
  on public.source_links for delete
  using (
    exists (
      select 1 from public.recipes
      where id = recipe_id and created_by = auth.uid()
    )
  );

-- saved_recipes: users manage their own bookmarks
create policy "Users can view own saved recipes"
  on public.saved_recipes for select
  using (auth.uid() = user_id);

create policy "Users can save recipes"
  on public.saved_recipes for insert
  with check (auth.uid() = user_id);

create policy "Users can unsave recipes"
  on public.saved_recipes for delete
  using (auth.uid() = user_id);

-- recipe_ratings: users manage own ratings, can read ratings on shared recipes
create policy "Users can view ratings on shared recipes"
  on public.recipe_ratings for select
  using (
    exists (
      select 1 from public.recipes
      where id = recipe_id and (created_by = auth.uid() or is_user_shared = true)
    )
  );

create policy "Users can insert own ratings"
  on public.recipe_ratings for insert
  with check (auth.uid() = user_id);

create policy "Users can update own ratings"
  on public.recipe_ratings for update
  using (auth.uid() = user_id);

create policy "Users can delete own ratings"
  on public.recipe_ratings for delete
  using (auth.uid() = user_id);

-- ────────────────────────────────────────────────────────────
-- 5. STORAGE BUCKETS
-- ────────────────────────────────────────────────────────────

insert into storage.buckets (id, name, public)
values
  ('recipe-images',  'recipe-images',  true),
  ('profile-photos', 'profile-photos', true);

-- recipe-images policies
create policy "Anyone can view recipe images"
  on storage.objects for select
  using (bucket_id = 'recipe-images');

create policy "Users can upload own recipe images"
  on storage.objects for insert
  with check (
    bucket_id = 'recipe-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update own recipe images"
  on storage.objects for update
  using (
    bucket_id = 'recipe-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete own recipe images"
  on storage.objects for delete
  using (
    bucket_id = 'recipe-images'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- profile-photos policies
create policy "Anyone can view profile photos"
  on storage.objects for select
  using (bucket_id = 'profile-photos');

create policy "Users can upload own profile photo"
  on storage.objects for insert
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can update own profile photo"
  on storage.objects for update
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete own profile photo"
  on storage.objects for delete
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
