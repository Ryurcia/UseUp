-- Creates a SECURITY DEFINER RPC that users can call to delete their own account.
-- All database rows cascade automatically because every user-linked table has
-- ON DELETE CASCADE referencing auth.users(id).
-- Storage objects must be removed explicitly since they live outside the schema.

CREATE OR REPLACE FUNCTION public.delete_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Remove profile photos and recipe images for this user
  DELETE FROM storage.objects
  WHERE bucket_id IN ('profile-pics', 'recipe-images')
    AND (storage.foldername(name))[1] = auth.uid()::text;

  -- Deleting the auth user cascades all rows in profiles, ingredients, recipes,
  -- saved_recipes, recipe_ratings, user_activity, recipe_reports, review_reports
  DELETE FROM auth.users WHERE id = auth.uid();
END;
$$;

-- Allow any authenticated user to call this (auth.uid() scopes the deletion)
GRANT EXECUTE ON FUNCTION public.delete_user() TO authenticated;
