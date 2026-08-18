-- Replaces the original delete_user function (002_delete_user_function.sql).
-- Wraps storage cleanup in an exception block so a storage failure never
-- aborts the critical auth.users deletion.

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
    where bucket_id in ('profile-pics', 'recipe-images')
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
