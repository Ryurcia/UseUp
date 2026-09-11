-- Collections (030_add_collections.sql) replace the single-select saved_recipes.category tag
-- introduced in 011_add_saved_recipe_category.sql. Existing category values are discarded
-- outright -- no backfill into a default Collection (confirmed product decision).
alter table public.saved_recipes drop column category;
