-- Index for fast ingredient name matching in recipe suggestions
create index if not exists idx_recipe_ingredients_name_lower
    on public.recipe_ingredients (lower(name));
