-- ============================================================
-- UseUp — Seed 20 Recipes
-- Run this in the Supabase SQL Editor (executes as postgres, bypasses RLS)
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Create UseUp system user
-- ────────────────────────────────────────────────────────────

INSERT INTO auth.users (
  instance_id, id, aud, role, email,
  encrypted_password, email_confirmed_at,
  created_at, updated_at, confirmation_token,
  raw_app_meta_data, raw_user_meta_data, is_super_admin
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-000000555570',
  'authenticated', 'authenticated',
  'system@useup.app',
  '', now(), now(), now(), '',
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"UseUp"}',
  false
);

-- Trigger auto-creates profiles row; update it:
UPDATE public.profiles
SET nickname = 'UseUp', display_name = 'UseUp'
WHERE id = '00000000-0000-0000-0000-000000555570';

-- ────────────────────────────────────────────────────────────
-- 2. Insert 20 recipes with ingredients
--    Using fixed recipe UUIDs so the image upload script can match them
-- ────────────────────────────────────────────────────────────

-- Recipe 1: Honey Garlic Salmon
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000001';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Honey Garlic Salmon',
    'Pan-seared salmon fillets glazed with a sticky honey garlic sauce.',
    25, 2,
    ARRAY[
      'Pat salmon dry and season with salt and pepper.',
      'Heat olive oil in a skillet over medium-high heat.',
      'Sear salmon skin-side up for 4 minutes until golden.',
      'Flip and cook 3 more minutes, then remove from pan.',
      'In the same pan, melt butter and sauté garlic for 30 seconds.',
      'Add honey, soy sauce, lemon juice, and red pepper flakes.',
      'Simmer until sauce thickens, about 2 minutes.',
      'Return salmon to pan, spoon glaze over fillets, and serve.'
    ],
    'american', true, 380, 34, 18, 18);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'salmon fillets', '2 fillets'),
    (recipe_id, 'used', 'honey', '3 tbsp'),
    (recipe_id, 'used', 'soy sauce', '2 tbsp'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'butter', '1 tbsp'),
    (recipe_id, 'used', 'olive oil', '1 tbsp'),
    (recipe_id, 'used', 'lemon juice', '1 tbsp'),
    (recipe_id, 'used', 'red pepper flakes', '1/4 tsp');
END $$;

-- Recipe 2: Carne Asada Street Tacos
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000002';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Carne Asada Street Tacos',
    'Charred skirt steak tacos with fresh cilantro, onion, and salsa verde.',
    35, 4,
    ARRAY[
      'Marinate steak in lime juice, olive oil, garlic, cumin, and chili powder for 20 minutes.',
      'Grill steak over high heat for 3-4 minutes per side for medium.',
      'Rest steak 5 minutes, then slice against the grain into thin strips.',
      'Warm tortillas on the grill or dry skillet.',
      'Assemble tacos with steak, diced onion, cilantro, and salsa verde.',
      'Squeeze fresh lime over top and serve immediately.'
    ],
    'mexican', true, 320, 28, 24, 12);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'skirt steak', '500g'),
    (recipe_id, 'used', 'lime juice', '3 tbsp'),
    (recipe_id, 'used', 'olive oil', '2 tbsp'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'cumin', '1 tsp'),
    (recipe_id, 'used', 'chili powder', '1 tsp'),
    (recipe_id, 'used', 'corn tortillas', '12 small'),
    (recipe_id, 'used', 'white onion', '1, diced'),
    (recipe_id, 'used', 'cilantro', '1/2 cup, chopped'),
    (recipe_id, 'used', 'salsa verde', '1/2 cup');
END $$;

-- Recipe 3: Wild Mushroom Risotto
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000003';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Wild Mushroom Risotto',
    'Creamy arborio rice with a medley of sautéed wild mushrooms and parmesan.',
    40, 4,
    ARRAY[
      'Sauté mushrooms in olive oil until golden brown, set aside.',
      'In the same pot, cook onion in butter until soft.',
      'Add garlic and rice, toast for 2 minutes until edges turn translucent.',
      'Pour in wine and stir until absorbed.',
      'Add warm broth one ladle at a time, stirring constantly.',
      'Continue for 18-20 minutes until rice is creamy and al dente.',
      'Fold in mushrooms, parmesan, and thyme.',
      'Season with salt and pepper, serve immediately.'
    ],
    'italian', true, 410, 10, 58, 14);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'arborio rice', '1.5 cups'),
    (recipe_id, 'used', 'mixed mushrooms', '300g, sliced'),
    (recipe_id, 'used', 'chicken broth', '4 cups, warm'),
    (recipe_id, 'used', 'white wine', '1/2 cup'),
    (recipe_id, 'used', 'onion', '1, finely diced'),
    (recipe_id, 'used', 'garlic', '2 cloves, minced'),
    (recipe_id, 'used', 'parmesan', '1/2 cup, grated'),
    (recipe_id, 'used', 'butter', '2 tbsp'),
    (recipe_id, 'used', 'olive oil', '1 tbsp'),
    (recipe_id, 'used', 'fresh thyme', '1 tsp');
END $$;

-- Recipe 4: Teriyaki Chicken Donburi
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000004';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Teriyaki Chicken Donburi',
    'Juicy teriyaki-glazed chicken thighs served over steamed rice with a soft egg.',
    25, 2,
    ARRAY[
      'Score chicken thighs and season lightly with salt.',
      'Pan-fry chicken skin-side down for 5 minutes until crispy.',
      'Flip and cook 4 more minutes.',
      'Mix soy sauce, mirin, sake, and sugar in a bowl.',
      'Pour sauce over chicken, simmer until glossy and thickened.',
      'Slice chicken and arrange over steamed rice.',
      'Fry eggs sunny-side up and place on top.',
      'Garnish with green onion and sesame seeds.'
    ],
    'japanese', true, 450, 36, 52, 10);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chicken thighs', '400g, boneless'),
    (recipe_id, 'used', 'soy sauce', '3 tbsp'),
    (recipe_id, 'used', 'mirin', '2 tbsp'),
    (recipe_id, 'used', 'sake', '1 tbsp'),
    (recipe_id, 'used', 'sugar', '1 tbsp'),
    (recipe_id, 'used', 'rice', '2 cups, cooked'),
    (recipe_id, 'used', 'eggs', '2'),
    (recipe_id, 'used', 'green onion', '2 stalks, sliced'),
    (recipe_id, 'used', 'sesame seeds', '1 tsp');
END $$;

-- Recipe 5: Butter Chicken
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000005';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Butter Chicken',
    'Tender chicken pieces in a rich, velvety tomato-cream sauce with aromatic spices.',
    45, 4,
    ARRAY[
      'Marinate chicken in yogurt, half the garam masala, and turmeric for 15 minutes.',
      'Sear marinated chicken in butter until browned, set aside.',
      'In the same pan, sauté onion, garlic, and ginger until fragrant.',
      'Add cumin, remaining garam masala, and chili powder; cook 1 minute.',
      'Pour in tomato puree and simmer 15 minutes.',
      'Stir in cream and return chicken to the sauce.',
      'Simmer 10 minutes until chicken is cooked through.',
      'Finish with a knob of butter and serve with rice or naan.'
    ],
    'indian', true, 420, 32, 16, 26);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chicken breast', '500g, cubed'),
    (recipe_id, 'used', 'yogurt', '1/2 cup'),
    (recipe_id, 'used', 'garam masala', '2 tsp'),
    (recipe_id, 'used', 'turmeric', '1/2 tsp'),
    (recipe_id, 'used', 'tomato puree', '400g'),
    (recipe_id, 'used', 'heavy cream', '1/2 cup'),
    (recipe_id, 'used', 'butter', '3 tbsp'),
    (recipe_id, 'used', 'onion', '1, diced'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'ginger', '1 tbsp, grated'),
    (recipe_id, 'used', 'cumin', '1 tsp'),
    (recipe_id, 'used', 'kashmiri chili powder', '1 tsp');
END $$;

-- Recipe 6: Green Curry with Chicken
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000006';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Green Curry with Chicken',
    'Fragrant coconut green curry with tender chicken, bamboo shoots, and Thai basil.',
    30, 4,
    ARRAY[
      'Heat oil and fry curry paste for 1 minute until fragrant.',
      'Add the thick cream from the top of the coconut milk, stir until oil separates.',
      'Add chicken and cook 3 minutes until sealed.',
      'Pour in remaining coconut milk, fish sauce, and palm sugar.',
      'Add Thai eggplant, bamboo shoots, and kaffir lime leaves.',
      'Simmer 15 minutes until chicken is cooked.',
      'Stir in Thai basil just before serving.',
      'Serve over jasmine rice.'
    ],
    'thai', true, 360, 28, 14, 22);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chicken thighs', '400g, sliced'),
    (recipe_id, 'used', 'green curry paste', '3 tbsp'),
    (recipe_id, 'used', 'coconut milk', '400ml'),
    (recipe_id, 'used', 'bamboo shoots', '1/2 cup'),
    (recipe_id, 'used', 'Thai basil', '1/2 cup'),
    (recipe_id, 'used', 'fish sauce', '2 tbsp'),
    (recipe_id, 'used', 'palm sugar', '1 tbsp'),
    (recipe_id, 'used', 'Thai eggplant', '4, quartered'),
    (recipe_id, 'used', 'kaffir lime leaves', '3'),
    (recipe_id, 'used', 'vegetable oil', '1 tbsp');
END $$;

-- Recipe 7: Kimchi Jjigae
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000007';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Kimchi Jjigae',
    'Hearty, spicy kimchi stew with pork belly, tofu, and green onions.',
    35, 3,
    ARRAY[
      'Sauté pork belly in sesame oil until fat renders, about 3 minutes.',
      'Add kimchi and stir-fry for 3 minutes until slightly caramelized.',
      'Add garlic, gochugaru, and gochujang; cook 1 minute.',
      'Pour in water and bring to a boil.',
      'Reduce heat and simmer 15 minutes.',
      'Add tofu cubes and simmer 5 more minutes.',
      'Garnish with sliced green onion.',
      'Serve bubbling hot with steamed rice.'
    ],
    'korean', true, 280, 22, 12, 16);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'aged kimchi', '2 cups, chopped'),
    (recipe_id, 'used', 'pork belly', '200g, sliced'),
    (recipe_id, 'used', 'firm tofu', '1 block, cubed'),
    (recipe_id, 'used', 'gochugaru', '1 tbsp'),
    (recipe_id, 'used', 'gochujang', '1 tbsp'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'sesame oil', '1 tbsp'),
    (recipe_id, 'used', 'green onion', '2 stalks, sliced');
END $$;

-- Recipe 8: Mapo Tofu
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000008';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Mapo Tofu',
    'Sichuan-style silken tofu in a fiery, numbing chili bean sauce with ground pork.',
    20, 3,
    ARRAY[
      'Gently blanch tofu cubes in salted water for 2 minutes, drain.',
      'Heat oil and brown ground pork, breaking into small pieces.',
      'Add doubanjiang and stir-fry for 1 minute until oil turns red.',
      'Add garlic and ginger, cook 30 seconds.',
      'Pour in 1 cup water and soy sauce, bring to a simmer.',
      'Gently slide in tofu, simmer 5 minutes.',
      'Stir in cornstarch slurry to thicken.',
      'Finish with ground Sichuan peppercorn and green onion.'
    ],
    'chinese', true, 260, 18, 10, 16);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'silken tofu', '1 block, cubed'),
    (recipe_id, 'used', 'ground pork', '150g'),
    (recipe_id, 'used', 'doubanjiang', '2 tbsp'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'ginger', '1 tsp, minced'),
    (recipe_id, 'used', 'Sichuan peppercorns', '1 tsp, ground'),
    (recipe_id, 'used', 'soy sauce', '1 tbsp'),
    (recipe_id, 'used', 'cornstarch', '1 tbsp'),
    (recipe_id, 'used', 'green onion', '2 stalks, sliced'),
    (recipe_id, 'used', 'vegetable oil', '2 tbsp');
END $$;

-- Recipe 9: Classic Ratatouille
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000009';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Classic Ratatouille',
    'Provençal vegetable stew with layers of zucchini, eggplant, and tomato.',
    50, 4,
    ARRAY[
      'Sauté onion and bell pepper in olive oil until soft.',
      'Add garlic and tomato paste, cook 2 minutes.',
      'Spread the sautéed mixture in the bottom of a baking dish.',
      'Alternate slices of zucchini, eggplant, and tomato in rows on top.',
      'Drizzle with olive oil and sprinkle herbes de Provence.',
      'Cover with foil and bake at 375°F for 40 minutes.',
      'Remove foil and bake 10 more minutes until edges are golden.',
      'Garnish with fresh basil and serve.'
    ],
    'french', true, 180, 4, 22, 10);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'zucchini', '2, sliced into rounds'),
    (recipe_id, 'used', 'eggplant', '1, sliced into rounds'),
    (recipe_id, 'used', 'tomatoes', '3, sliced into rounds'),
    (recipe_id, 'used', 'red bell pepper', '1, diced'),
    (recipe_id, 'used', 'onion', '1, diced'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'tomato paste', '2 tbsp'),
    (recipe_id, 'used', 'olive oil', '3 tbsp'),
    (recipe_id, 'used', 'herbes de Provence', '1 tsp'),
    (recipe_id, 'used', 'fresh basil', 'for garnish');
END $$;

-- Recipe 10: Chicken Souvlaki with Tzatziki
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000010';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Chicken Souvlaki with Tzatziki',
    'Marinated grilled chicken skewers with creamy cucumber-yogurt sauce.',
    30, 4,
    ARRAY[
      'Marinate chicken in lemon juice, olive oil, oregano, and garlic for 20 minutes.',
      'Thread chicken onto skewers.',
      'Grill skewers over medium-high heat, 4 minutes per side.',
      'For tzatziki: mix yogurt, grated cucumber, dill, a squeeze of lemon, and salt.',
      'Warm pita bread on the grill.',
      'Serve skewers with tzatziki and warm pita.'
    ],
    'greek', true, 340, 36, 8, 18);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chicken breast', '500g, cubed'),
    (recipe_id, 'used', 'lemon juice', '3 tbsp'),
    (recipe_id, 'used', 'olive oil', '3 tbsp'),
    (recipe_id, 'used', 'oregano', '2 tsp, dried'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'Greek yogurt', '1 cup'),
    (recipe_id, 'used', 'cucumber', '1/2, grated and squeezed'),
    (recipe_id, 'used', 'dill', '1 tbsp, fresh'),
    (recipe_id, 'used', 'pita bread', '4');
END $$;

-- Recipe 11: Sinigang na Baboy
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000011';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Sinigang na Baboy',
    'Tangy tamarind pork soup with vegetables — the ultimate Filipino comfort food.',
    50, 6,
    ARRAY[
      'Boil pork ribs in water, skim off scum, and simmer 20 minutes.',
      'Add tomatoes and onion, cook 5 minutes.',
      'Stir in tamarind paste and fish sauce.',
      'Add daikon radish and simmer 10 minutes until tender.',
      'Add string beans and green chili, cook 3 minutes.',
      'Add water spinach last, cook just until wilted.',
      'Adjust sourness with more tamarind and season with fish sauce.',
      'Serve hot with steamed rice.'
    ],
    'filipino', true, 290, 24, 18, 14);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'pork ribs', '500g, cut into pieces'),
    (recipe_id, 'used', 'tamarind paste', '2 tbsp'),
    (recipe_id, 'used', 'tomatoes', '2, quartered'),
    (recipe_id, 'used', 'onion', '1, quartered'),
    (recipe_id, 'used', 'water spinach (kangkong)', '2 cups'),
    (recipe_id, 'used', 'daikon radish', '1 cup, sliced'),
    (recipe_id, 'used', 'string beans', '1 cup, cut into 2-inch pieces'),
    (recipe_id, 'used', 'fish sauce', '2 tbsp'),
    (recipe_id, 'used', 'green chili', '2');
END $$;

-- Recipe 12: Shakshuka
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000012';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Shakshuka',
    'Eggs poached in a smoky, spiced tomato and pepper sauce.',
    25, 3,
    ARRAY[
      'Sauté onion and bell pepper in olive oil until soft.',
      'Add garlic, cumin, paprika, and cayenne; cook 1 minute.',
      'Pour in crushed tomatoes and simmer 10 minutes until thickened.',
      'Make 4 wells in the sauce and crack an egg into each.',
      'Cover and cook 5-7 minutes until egg whites are set but yolks are runny.',
      'Crumble feta over top and garnish with parsley.',
      'Serve straight from the skillet with crusty bread.'
    ],
    'mediterranean', true, 240, 14, 16, 14);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'eggs', '4'),
    (recipe_id, 'used', 'crushed tomatoes', '400g'),
    (recipe_id, 'used', 'red bell pepper', '1, diced'),
    (recipe_id, 'used', 'onion', '1, diced'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'cumin', '1 tsp'),
    (recipe_id, 'used', 'paprika', '1 tsp'),
    (recipe_id, 'used', 'cayenne', '1/4 tsp'),
    (recipe_id, 'used', 'olive oil', '2 tbsp'),
    (recipe_id, 'used', 'feta cheese', '1/4 cup, crumbled'),
    (recipe_id, 'used', 'fresh parsley', 'for garnish');
END $$;

-- Recipe 13: Chicken Shawarma Bowl
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000013';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Chicken Shawarma Bowl',
    'Warmly spiced roasted chicken with garlic sauce, pickles, and fluffy rice.',
    35, 4,
    ARRAY[
      'Mix all spices with garlic, lemon juice, and olive oil.',
      'Marinate chicken in the spice mixture for at least 15 minutes.',
      'Roast chicken at 425°F for 20-25 minutes until charred edges.',
      'Rest 5 minutes, then slice into strips.',
      'Make tahini sauce: whisk tahini with lemon juice and water until pourable.',
      'Assemble bowls with rice, sliced chicken, pickled turnips, and tahini drizzle.'
    ],
    'middleEastern', true, 390, 34, 32, 14);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chicken thighs', '500g, boneless'),
    (recipe_id, 'used', 'cumin', '1.5 tsp'),
    (recipe_id, 'used', 'coriander', '1 tsp'),
    (recipe_id, 'used', 'turmeric', '1/2 tsp'),
    (recipe_id, 'used', 'paprika', '1 tsp'),
    (recipe_id, 'used', 'cinnamon', '1/4 tsp'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'lemon juice', '2 tbsp'),
    (recipe_id, 'used', 'olive oil', '2 tbsp'),
    (recipe_id, 'used', 'rice', '2 cups, cooked'),
    (recipe_id, 'used', 'pickled turnips', '1/4 cup'),
    (recipe_id, 'used', 'tahini', '2 tbsp');
END $$;

-- Recipe 14: Pho Bo
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000014';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Pho Bo',
    'Aromatic Vietnamese beef noodle soup with fresh herbs and rice noodles.',
    45, 4,
    ARRAY[
      'Char onion and ginger under a broiler until blackened.',
      'Simmer broth with star anise, cinnamon, charred onion, and ginger for 20 minutes.',
      'Strain broth and season with fish sauce.',
      'Cook rice noodles according to package and divide into bowls.',
      'Arrange raw beef slices on top of noodles.',
      'Ladle boiling broth over beef — it will cook instantly.',
      'Serve with bean sprouts, Thai basil, lime, and hoisin on the side.'
    ],
    'asian', true, 350, 28, 36, 8);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef sirloin', '300g, thinly sliced'),
    (recipe_id, 'used', 'rice noodles', '200g'),
    (recipe_id, 'used', 'beef broth', '6 cups'),
    (recipe_id, 'used', 'star anise', '2'),
    (recipe_id, 'used', 'cinnamon stick', '1'),
    (recipe_id, 'used', 'ginger', '3-inch piece, halved'),
    (recipe_id, 'used', 'onion', '1, halved and charred'),
    (recipe_id, 'used', 'fish sauce', '2 tbsp'),
    (recipe_id, 'used', 'bean sprouts', '1 cup'),
    (recipe_id, 'used', 'Thai basil', '1/2 cup'),
    (recipe_id, 'used', 'lime', '2, cut in wedges'),
    (recipe_id, 'used', 'hoisin sauce', 'for serving');
END $$;

-- Recipe 15: Crispy Carnitas
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000015';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Crispy Carnitas',
    'Slow-braised pulled pork with crispy edges, finished with fresh orange and lime.',
    60, 6,
    ARRAY[
      'Place pork in a heavy pot with orange juice, lime juice, garlic, cumin, oregano, bay leaves, and salt.',
      'Add just enough water to cover pork halfway.',
      'Bring to a boil, then reduce to a low simmer.',
      'Cook uncovered for 2 hours until liquid evaporates and pork is tender.',
      'Pork will begin to fry in its own rendered fat — let it crisp up.',
      'Shred with two forks, pressing some pieces against the pan to get extra crispy edges.',
      'Squeeze fresh lime juice over top and serve with tortillas.'
    ],
    'mexican', true, 340, 32, 4, 22);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'pork shoulder', '1kg, cut into chunks'),
    (recipe_id, 'used', 'orange juice', '1/2 cup'),
    (recipe_id, 'used', 'lime juice', '2 tbsp'),
    (recipe_id, 'used', 'garlic', '5 cloves, smashed'),
    (recipe_id, 'used', 'cumin', '1 tsp'),
    (recipe_id, 'used', 'oregano', '1 tsp, dried'),
    (recipe_id, 'used', 'bay leaves', '2'),
    (recipe_id, 'used', 'lard or oil', '2 tbsp'),
    (recipe_id, 'used', 'salt', '1 tsp');
END $$;

-- Recipe 16: Pasta alla Norma
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000016';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Pasta alla Norma',
    'Sicilian pasta with fried eggplant, tomato sauce, and ricotta salata.',
    30, 3,
    ARRAY[
      'Salt eggplant cubes and let drain 15 minutes, then pat dry.',
      'Fry eggplant in olive oil until golden brown on all sides, drain on paper towels.',
      'In the same pan, sauté garlic and red pepper flakes for 30 seconds.',
      'Add crushed tomatoes and simmer 15 minutes.',
      'Cook penne until al dente, reserve 1/2 cup pasta water.',
      'Toss pasta with sauce, adding pasta water for silkiness.',
      'Fold in fried eggplant and tear fresh basil over top.',
      'Finish with grated ricotta salata.'
    ],
    'italian', true, 380, 12, 54, 14);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'penne', '350g'),
    (recipe_id, 'used', 'eggplant', '1 large, cubed'),
    (recipe_id, 'used', 'crushed tomatoes', '400g'),
    (recipe_id, 'used', 'garlic', '3 cloves, sliced'),
    (recipe_id, 'used', 'olive oil', '4 tbsp'),
    (recipe_id, 'used', 'red pepper flakes', '1/4 tsp'),
    (recipe_id, 'used', 'ricotta salata', '1/3 cup, grated'),
    (recipe_id, 'used', 'fresh basil', '1/4 cup');
END $$;

-- Recipe 17: Chana Masala
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000017';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Chana Masala',
    'Spiced chickpea curry in a tangy tomato-onion sauce — hearty and fully vegan.',
    30, 4,
    ARRAY[
      'Heat oil and pop cumin seeds until fragrant.',
      'Add onion and cook until deeply golden, about 8 minutes.',
      'Add garlic and ginger, cook 1 minute.',
      'Stir in coriander, turmeric, and amchur; toast 30 seconds.',
      'Add crushed tomatoes and simmer 10 minutes.',
      'Add chickpeas with 1/2 cup water, simmer 15 minutes until thick.',
      'Stir in garam masala and adjust salt.',
      'Garnish with cilantro and serve with rice or naan.'
    ],
    'indian', true, 280, 12, 40, 8);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chickpeas', '2 cans, drained'),
    (recipe_id, 'used', 'crushed tomatoes', '400g'),
    (recipe_id, 'used', 'onion', '1 large, diced'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'ginger', '1 tbsp, grated'),
    (recipe_id, 'used', 'cumin seeds', '1 tsp'),
    (recipe_id, 'used', 'coriander', '1.5 tsp'),
    (recipe_id, 'used', 'garam masala', '1 tsp'),
    (recipe_id, 'used', 'turmeric', '1/2 tsp'),
    (recipe_id, 'used', 'amchur powder', '1 tsp'),
    (recipe_id, 'used', 'vegetable oil', '2 tbsp'),
    (recipe_id, 'used', 'cilantro', 'for garnish');
END $$;

-- Recipe 18: Gyudon
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000018';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Gyudon',
    'Sweet and savory soy-braised beef over steaming rice — Japanese comfort food.',
    20, 2,
    ARRAY[
      'Combine dashi, soy sauce, mirin, sake, and sugar in a pan.',
      'Bring to a simmer and add sliced onion.',
      'Cook onion until soft and translucent, about 5 minutes.',
      'Lay beef slices over onion and simmer 3 minutes until just cooked.',
      'Crack eggs into the pan, cover, and cook 1 minute for soft-set eggs.',
      'Spoon beef, onion, and egg over hot steamed rice.',
      'Drizzle with the braising liquid and garnish with pickled ginger.'
    ],
    'japanese', true, 480, 26, 56, 16);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef ribeye', '300g, thinly sliced'),
    (recipe_id, 'used', 'onion', '1 large, thinly sliced'),
    (recipe_id, 'used', 'soy sauce', '3 tbsp'),
    (recipe_id, 'used', 'mirin', '2 tbsp'),
    (recipe_id, 'used', 'sake', '2 tbsp'),
    (recipe_id, 'used', 'sugar', '1 tbsp'),
    (recipe_id, 'used', 'dashi stock', '1/2 cup'),
    (recipe_id, 'used', 'rice', '2 cups, cooked'),
    (recipe_id, 'used', 'eggs', '2'),
    (recipe_id, 'used', 'pickled ginger', 'for garnish');
END $$;

-- Recipe 19: Pad Kra Pao
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000019';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Pad Kra Pao',
    'Wok-fired minced chicken with holy basil, chili, and a crispy fried egg.',
    15, 2,
    ARRAY[
      'Heat 1 tbsp oil in a wok over high heat until smoking.',
      'Add garlic and chilies, stir 10 seconds.',
      'Add ground chicken, break apart, and cook until no longer pink.',
      'Add soy sauce, oyster sauce, fish sauce, and sugar; toss well.',
      'Kill the heat and fold in holy basil until just wilted.',
      'In a separate pan, fry eggs in remaining oil until edges are crispy.',
      'Serve chicken over rice, topped with a fried egg.'
    ],
    'thai', true, 340, 30, 28, 12);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'ground chicken', '400g'),
    (recipe_id, 'used', 'holy basil leaves', '1 cup, packed'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'Thai chilies', '3, minced'),
    (recipe_id, 'used', 'soy sauce', '1 tbsp'),
    (recipe_id, 'used', 'oyster sauce', '2 tbsp'),
    (recipe_id, 'used', 'fish sauce', '1 tbsp'),
    (recipe_id, 'used', 'sugar', '1 tsp'),
    (recipe_id, 'used', 'eggs', '2'),
    (recipe_id, 'used', 'vegetable oil', '3 tbsp'),
    (recipe_id, 'used', 'rice', '2 cups, cooked');
END $$;

-- Recipe 20: Coq au Vin
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000020';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Coq au Vin',
    'Braised chicken in red wine with mushrooms, pearl onions, and lardons.',
    60, 4,
    ARRAY[
      'Season chicken legs with salt and pepper, brown in butter on all sides.',
      'Remove chicken, add lardons and cook until crispy.',
      'Add pearl onions and mushrooms, sauté until golden.',
      'Stir in garlic and tomato paste, cook 1 minute.',
      'Sprinkle flour over vegetables and stir.',
      'Pour in red wine and broth, scraping up browned bits.',
      'Return chicken to the pot, add thyme and bay leaf.',
      'Cover and braise at 325°F for 1.5 hours until chicken falls off the bone.',
      'Remove thyme and bay leaf, adjust seasoning, and serve.'
    ],
    'french', true, 420, 36, 12, 22);

  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chicken legs', '4'),
    (recipe_id, 'used', 'red wine', '2 cups'),
    (recipe_id, 'used', 'bacon lardons', '100g'),
    (recipe_id, 'used', 'pearl onions', '12, peeled'),
    (recipe_id, 'used', 'mushrooms', '200g, quartered'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'tomato paste', '1 tbsp'),
    (recipe_id, 'used', 'chicken broth', '1 cup'),
    (recipe_id, 'used', 'butter', '2 tbsp'),
    (recipe_id, 'used', 'flour', '1 tbsp'),
    (recipe_id, 'used', 'fresh thyme', '3 sprigs'),
    (recipe_id, 'used', 'bay leaf', '1');
END $$;
