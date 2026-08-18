-- Drop and recreate profile-photos storage policies using split_part
-- instead of storage.foldername() which may not be available in all versions.

drop policy if exists "Users can upload own profile photo" on storage.objects;
drop policy if exists "Users can update own profile photo" on storage.objects;
drop policy if exists "Users can delete own profile photo" on storage.objects;
drop policy if exists "Anyone can view profile photos" on storage.objects;

create policy "Anyone can view profile photos"
  on storage.objects for select
  using (bucket_id = 'profile-photos');

create policy "Users can upload own profile photo"
  on storage.objects for insert
  with check (
    bucket_id = 'profile-photos'
    and split_part(name, '/', 1) = auth.uid()::text
  );

create policy "Users can update own profile photo"
  on storage.objects for update
  using (
    bucket_id = 'profile-photos'
    and split_part(name, '/', 1) = auth.uid()::text
  );

create policy "Users can delete own profile photo"
  on storage.objects for delete
  using (
    bucket_id = 'profile-photos'
    and split_part(name, '/', 1) = auth.uid()::text
  );
