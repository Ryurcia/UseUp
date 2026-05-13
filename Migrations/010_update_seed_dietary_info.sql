-- Update seed recipes with diet_type and dietary_restrictions
-- Run after 009_add_recipe_dietary_info.sql

-- 1. Honey Garlic Salmon — pescatarian, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'pescatarian',
    dietary_restrictions = ARRAY['Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000001';

-- 2. Carne Asada Street Tacos — any, dairy-free, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000002';

-- 3. Wild Mushroom Risotto — vegetarian, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'vegetarian',
    dietary_restrictions = ARRAY['Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000003';

-- 4. Teriyaki Chicken Donburi — any, dairy-free, nut-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000004';

-- 5. Butter Chicken — any, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000005';

-- 6. Green Curry with Chicken — any, gluten-free, dairy-free, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000006';

-- 7. Kimchi Jjigae — any, dairy-free, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000007';

-- 8. Mapo Tofu — any, dairy-free, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000008';

-- 9. Classic Ratatouille — vegan, gluten-free, dairy-free, nut-free, soy-free, egg-free, shellfish-free, low sodium
UPDATE public.recipes
SET diet_type = 'vegan',
    dietary_restrictions = ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Soy-Free', 'Egg-Free', 'Shellfish-Free', 'Low Sodium']
WHERE id = 'a0000001-0000-4000-8000-000000000009';

-- 10. Chicken Souvlaki with Tzatziki — any, nut-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Nut-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000010';

-- 11. Sinigang na Baboy — any, gluten-free, dairy-free, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000011';

-- 12. Shakshuka — vegetarian, gluten-free, nut-free, soy-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'vegetarian',
    dietary_restrictions = ARRAY['Gluten-Free', 'Nut-Free', 'Soy-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000012';

-- 13. Chicken Shawarma Bowl — any, dairy-free, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000013';

-- 14. Pho Bo — any, dairy-free, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000014';

-- 15. Crispy Carnitas — any, gluten-free, dairy-free, nut-free, soy-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Soy-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000015';

-- 16. Pasta alla Norma — vegetarian, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'vegetarian',
    dietary_restrictions = ARRAY['Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000016';

-- 17. Chana Masala — vegan, gluten-free, dairy-free, nut-free, soy-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'vegan',
    dietary_restrictions = ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Soy-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000017';

-- 18. Gyudon — any, dairy-free, nut-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000018';

-- 19. Pad Kra Pao — any, dairy-free, nut-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000019';

-- 20. Coq au Vin — any, nut-free, egg-free, shellfish-free
UPDATE public.recipes
SET diet_type = 'any',
    dietary_restrictions = ARRAY['Nut-Free', 'Egg-Free', 'Shellfish-Free']
WHERE id = 'a0000001-0000-4000-8000-000000000020';
