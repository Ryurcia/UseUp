-- ============================================================
-- Fix image_path on the 60 Greek/Korean/Ethiopian seed recipes:
-- they were written with an erroneous leading 'recipe-images/'
-- segment. CachedRecipeImage does
-- `storage.from("recipe-images").download(path: imagePath)`,
-- so imagePath must be relative to that bucket, not include the
-- bucket name itself.
-- ============================================================

UPDATE public.recipes
SET image_path = regexp_replace(image_path, '^recipe-images/', '')
WHERE created_by = '00000000-0000-0000-0000-000000555570'
  AND image_path LIKE 'recipe-images/%';
