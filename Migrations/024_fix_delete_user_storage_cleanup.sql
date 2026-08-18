-- Replaces public.delete_user() (023_fix_delete_user_function.sql).
-- profile-pics uses flat filenames ({user_id}, no "/" — see 014_profile_pics_bucket.sql),
-- so storage.foldername(name)[1] is always NULL for that bucket and the cleanup
-- silently matched zero rows, leaving avatar files orphaned. recipe-images still
-- uses nested {user_id}/{uuid}.jpg paths, so it keeps the foldername-based match.
-- Storage cleanup stays wrapped in an exception block so a storage failure can
-- never abort the critical auth.users deletion.

create or replace function public.delete_user()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Best-effort: remove profile photos and recipe images.
  -- Wrapped in exception block so storage errors cannot abort the deletion.
  begin
    delete from storage.objects
    where bucket_id = 'profile-pics'
      and name = (auth.uid())::text;

    delete from storage.objects
    where bucket_id = 'recipe-images'
      and (storage.foldername(name))[1] = (auth.uid())::text;
  exception when others then
    null;
  end;

  -- Deleting from auth.users cascades to: profiles, ingredients, recipes,
  -- saved_recipes, recipe_ratings, user_activity, recipe_reports, review_reports.
  delete from auth.users where id = auth.uid();
end;
$$;

grant execute on function public.delete_user() to authenticated;
revoke execute on function public.delete_user() from anon, public;
