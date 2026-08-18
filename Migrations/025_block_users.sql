-- Lets a user block another user, hiding that user's shared recipes and
-- reviews from them (Apple App Store Guideline 1.2(c) requires the ability
-- to block abusive users in apps with user-generated content).

create table public.blocked_users (
  blocker_id  uuid not null references auth.users(id) on delete cascade,
  blocked_id  uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocked_users_no_self_block check (blocker_id <> blocked_id)
);

alter table public.blocked_users enable row level security;

create policy "Users can view their own blocks"
  on public.blocked_users for select
  to authenticated
  using (auth.uid() = blocker_id);

create policy "Users can block others"
  on public.blocked_users for insert
  to authenticated
  with check (auth.uid() = blocker_id);

create policy "Users can unblock others"
  on public.blocked_users for delete
  to authenticated
  using (auth.uid() = blocker_id);

-- Hide shared recipes authored by anyone the viewer has blocked.
drop policy "Users can view shared recipes" on public.recipes;
create policy "Users can view shared recipes"
  on public.recipes for select
  using (
    is_user_shared = true
    and created_by not in (
      select blocked_id from public.blocked_users where blocker_id = auth.uid()
    )
  );

-- Hide ratings/reviews authored by anyone the viewer has blocked.
drop policy "Users can view ratings on shared recipes" on public.recipe_ratings;
create policy "Users can view ratings on shared recipes"
  on public.recipe_ratings for select
  using (
    exists (
      select 1 from public.recipes
      where id = recipe_id and (created_by = auth.uid() or is_user_shared = true)
    )
    and user_id not in (
      select blocked_id from public.blocked_users where blocker_id = auth.uid()
    )
  );
