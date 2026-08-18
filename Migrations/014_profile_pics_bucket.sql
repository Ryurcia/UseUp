-- Create profile-pics bucket with flat per-user paths.
-- File path = {user_id} (no subfolder), so RLS checks name directly
-- instead of storage.foldername() which is not available in all versions.

insert into storage.buckets (id, name, public)
values ('profile-pics', 'profile-pics', true)
on conflict (id) do nothing;

-- Drop old profile-photos policies if they exist
drop policy if exists "Anyone can view profile photos" on storage.objects;
drop policy if exists "Users can upload own profile photo" on storage.objects;
drop policy if exists "Users can update own profile photo" on storage.objects;
drop policy if exists "Users can delete own profile photo" on storage.objects;

-- profile-pics policies
create policy "Anyone can view profile pics"
  on storage.objects for select
  using (bucket_id = 'profile-pics');

create policy "Users can upload own profile pic"
  on storage.objects for insert
  with check (
    bucket_id = 'profile-pics'
    and name = auth.uid()::text
  );

create policy "Users can update own profile pic"
  on storage.objects for update
  using (
    bucket_id = 'profile-pics'
    and name = auth.uid()::text
  );

create policy "Users can delete own profile pic"
  on storage.objects for delete
  using (
    bucket_id = 'profile-pics'
    and name = auth.uid()::text
  );
