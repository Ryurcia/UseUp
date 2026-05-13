-- ============================================================
-- UseUp — Seed 20 Additional Recipes (IDs 21–40)
-- ============================================================
-- ⚠️  IMPORTANT: Run this file in TWO separate steps in the
--     Supabase SQL Editor. PostgreSQL requires enum values to
--     be committed before they can be used in the same session.
--
-- STEP 1 — Paste and run ONLY the ALTER TYPE block below:
-- ────────────────────────────────────────────────────────────
ALTER TYPE cuisine_type ADD VALUE IF NOT EXISTS 'spanish';
ALTER TYPE cuisine_type ADD VALUE IF NOT EXISTS 'vietnamese';
ALTER TYPE cuisine_type ADD VALUE IF NOT EXISTS 'brazilian';
ALTER TYPE cuisine_type ADD VALUE IF NOT EXISTS 'ethiopian';
ALTER TYPE cuisine_type ADD VALUE IF NOT EXISTS 'turkish';
ALTER TYPE cuisine_type ADD VALUE IF NOT EXISTS 'peruvian';
ALTER TYPE cuisine_type ADD VALUE IF NOT EXISTS 'caribbean';
-- ────────────────────────────────────────────────────────────
-- STEP 2 — After Step 1 succeeds, paste and run everything
--          below this line (the DO $$ recipe blocks).
-- ────────────────────────────────────────────────────────────

-- ─── Recipe 21: Spaghetti Carbonara ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000021';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Spaghetti Carbonara',
    'Classic Roman pasta with a silky egg-and-pecorino sauce, crispy guanciale, and cracked black pepper.',
    25, 2,
    ARRAY[
      'Bring a large pot of salted water to a boil and cook spaghetti until al dente.',
      'Render guanciale in a cold dry skillet over medium heat until crispy; set aside and keep fat in pan.',
      'Whisk together 2 eggs, 1 yolk, grated pecorino, and a generous amount of black pepper.',
      'Reserve 1 cup of pasta cooking water, then drain.',
      'Remove skillet from heat. Add drained pasta and toss with guanciale and its fat.',
      'Pour egg mixture over pasta off the heat, tossing constantly while adding pasta water a splash at a time.',
      'Toss until sauce is silky and clings to every strand. Serve immediately with extra pecorino.'
    ],
    'italian', true, 580, 24, 68, 22, 'any', ARRAY['Nut-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000021.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'spaghetti', '200g'),
    (recipe_id, 'used', 'guanciale or pancetta', '100g, diced'),
    (recipe_id, 'used', 'eggs', '2 whole + 1 yolk'),
    (recipe_id, 'used', 'pecorino romano', '60g, finely grated'),
    (recipe_id, 'used', 'black pepper', '1 tsp, coarsely ground'),
    (recipe_id, 'used', 'salt', 'for pasta water');
END $$;

-- ─── Recipe 22: Chicken Tikka Masala ─────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000022';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Chicken Tikka Masala',
    'Char-grilled chicken in a rich, creamy tomato-spice sauce — the ultimate crowd-pleasing curry.',
    45, 4,
    ARRAY[
      'Marinate chicken in yogurt, half the garam masala, turmeric, and chili powder for 20 minutes.',
      'Thread onto skewers and grill or broil until charred and cooked through, about 8 minutes.',
      'In a large skillet, melt butter and sauté onion until golden, about 8 minutes.',
      'Add garlic, ginger, cumin, coriander, remaining garam masala, and paprika; cook 1 minute.',
      'Pour in crushed tomatoes and simmer 15 minutes until slightly reduced.',
      'Blend sauce until smooth, then return to pan. Stir in heavy cream.',
      'Add grilled chicken and simmer 5 minutes. Garnish with cilantro and serve with basmati rice or naan.'
    ],
    'indian', true, 420, 36, 18, 24, 'any', ARRAY['Gluten-Free', 'Nut-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000022.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chicken breast', '600g, cubed'),
    (recipe_id, 'used', 'plain yogurt', '1/2 cup'),
    (recipe_id, 'used', 'garam masala', '2 tsp'),
    (recipe_id, 'used', 'turmeric', '1/2 tsp'),
    (recipe_id, 'used', 'kashmiri chili powder', '1 tsp'),
    (recipe_id, 'used', 'crushed tomatoes', '400g'),
    (recipe_id, 'used', 'heavy cream', '1/3 cup'),
    (recipe_id, 'used', 'butter', '2 tbsp'),
    (recipe_id, 'used', 'onion', '1 large, diced'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'ginger', '1 tbsp, grated'),
    (recipe_id, 'used', 'cilantro', 'for garnish');
END $$;

-- ─── Recipe 23: Vegan Buddha Bowl ────────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000023';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Vegan Buddha Bowl',
    'A nourishing bowl of roasted chickpeas, quinoa, fresh veggies, and a lemon-tahini drizzle.',
    30, 2,
    ARRAY[
      'Preheat oven to 400°F. Toss chickpeas with olive oil, smoked paprika, and cumin; roast 25 minutes until crispy.',
      'Cook quinoa according to package directions and season with salt.',
      'Massage kale with a little olive oil and lemon juice until slightly softened.',
      'Slice cucumber, halve cherry tomatoes, and slice avocado.',
      'Whisk tahini with lemon juice, garlic, and 2–3 tbsp water until pourable.',
      'Arrange quinoa, kale, roasted chickpeas, cucumber, tomatoes, and avocado in bowls.',
      'Drizzle with tahini dressing and sprinkle with sesame seeds and red pepper flakes.'
    ],
    'other', true, 380, 14, 52, 16, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000023.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'cooked quinoa', '2 cups'),
    (recipe_id, 'used', 'chickpeas', '1 can, drained and dried'),
    (recipe_id, 'used', 'kale', '2 cups, chopped'),
    (recipe_id, 'used', 'avocado', '1, sliced'),
    (recipe_id, 'used', 'cucumber', '1/2, sliced'),
    (recipe_id, 'used', 'cherry tomatoes', '1 cup, halved'),
    (recipe_id, 'used', 'tahini', '3 tbsp'),
    (recipe_id, 'used', 'lemon juice', '2 tbsp'),
    (recipe_id, 'used', 'smoked paprika', '1 tsp'),
    (recipe_id, 'used', 'olive oil', '2 tbsp'),
    (recipe_id, 'used', 'sesame seeds', '1 tsp');
END $$;

-- ─── Recipe 24: Korean Beef Bulgogi ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000024';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Korean Beef Bulgogi',
    'Tender marinated beef ribeye grilled to perfection — sweet, savory, and smoky in every bite.',
    30, 4,
    ARRAY[
      'Freeze beef 20 minutes for easier slicing, then slice paper-thin against the grain.',
      'Blend grated pear, soy sauce, sesame oil, sugar, garlic, and ginger into a marinade.',
      'Toss beef with marinade and sliced onion; marinate at least 15 minutes.',
      'Heat a cast-iron skillet or grill pan over high heat until smoking.',
      'Cook beef in a single layer for 1–2 minutes per side until caramelized — work in batches.',
      'Serve over steamed rice, garnished with green onions, sesame seeds, and kimchi on the side.'
    ],
    'korean', true, 340, 28, 18, 16, 'any', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000024.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef ribeye', '500g, thinly sliced'),
    (recipe_id, 'used', 'soy sauce', '3 tbsp'),
    (recipe_id, 'used', 'sesame oil', '1 tbsp'),
    (recipe_id, 'used', 'Asian pear', '1/2, grated'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'sugar', '1 tbsp'),
    (recipe_id, 'used', 'onion', '1/2, thinly sliced'),
    (recipe_id, 'used', 'green onions', '3 stalks, sliced'),
    (recipe_id, 'used', 'sesame seeds', '1 tsp'),
    (recipe_id, 'used', 'rice', '4 cups, cooked');
END $$;

-- ─── Recipe 25: High-Protein Breakfast Bowl ──────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000025';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'High-Protein Breakfast Bowl',
    'Scrambled egg whites, turkey, cottage cheese, and sautéed spinach — 48g protein to fuel your morning.',
    20, 1,
    ARRAY[
      'Heat olive oil in a non-stick skillet over medium heat. Add spinach and sauté until wilted, 1–2 minutes.',
      'Push spinach to the side. Add diced turkey and warm through.',
      'Whisk egg whites and whole eggs together with salt and pepper.',
      'Pour eggs into the skillet and scramble gently over medium-low heat until just set.',
      'Halve cherry tomatoes and slice avocado.',
      'Spoon eggs, turkey, and spinach into a bowl. Add cottage cheese, tomatoes, and avocado alongside.',
      'Season with salt, pepper, and a squeeze of hot sauce if desired.'
    ],
    'american', true, 480, 48, 12, 22, 'any', ARRAY['Gluten-Free', 'Nut-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000025.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'egg whites', '6'),
    (recipe_id, 'used', 'whole eggs', '2'),
    (recipe_id, 'used', 'turkey breast', '80g, diced'),
    (recipe_id, 'used', 'low-fat cottage cheese', '1/2 cup'),
    (recipe_id, 'used', 'baby spinach', '2 cups'),
    (recipe_id, 'used', 'cherry tomatoes', '1/2 cup, halved'),
    (recipe_id, 'used', 'avocado', '1/4, sliced'),
    (recipe_id, 'used', 'olive oil', '1 tsp');
END $$;

-- ─── Recipe 26: Pad Thai ─────────────────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000026';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Pad Thai',
    'Iconic Thai stir-fried rice noodles with chicken, egg, bean sprouts, and crushed peanuts.',
    25, 2,
    ARRAY[
      'Soak rice noodles in warm water for 20 minutes until pliable; drain.',
      'Stir together tamarind paste, fish sauce, palm sugar, and sriracha in a small bowl.',
      'Heat oil in a wok over high heat. Stir-fry chicken until cooked through; push to side.',
      'Add garlic and shallots, cook 30 seconds. Add noodles and toss to coat.',
      'Pour sauce over noodles and stir-fry 2 minutes until noodles are tender and glossy.',
      'Push noodles aside, crack in eggs, scramble briefly, then toss everything together.',
      'Remove from heat. Mix in bean sprouts and green onions. Serve with crushed peanuts and lime wedges.'
    ],
    'thai', true, 480, 22, 58, 18, 'any', ARRAY['Gluten-Free', 'Dairy-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000026.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'rice noodles', '200g'),
    (recipe_id, 'used', 'chicken breast', '200g, sliced'),
    (recipe_id, 'used', 'eggs', '2'),
    (recipe_id, 'used', 'bean sprouts', '1 cup'),
    (recipe_id, 'used', 'tamarind paste', '2 tbsp'),
    (recipe_id, 'used', 'fish sauce', '2 tbsp'),
    (recipe_id, 'used', 'palm sugar', '1 tbsp'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'shallots', '2, minced'),
    (recipe_id, 'used', 'crushed peanuts', '3 tbsp'),
    (recipe_id, 'used', 'green onions', '3 stalks, sliced'),
    (recipe_id, 'used', 'lime', '1, cut into wedges');
END $$;

-- ─── Recipe 27: Greek Moussaka ───────────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000027';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Greek Moussaka',
    'Layered oven-baked casserole of spiced lamb, fried eggplant, and golden béchamel.',
    80, 6,
    ARRAY[
      'Slice eggplant into 1cm rounds, salt, and drain 20 minutes. Pat dry and fry in olive oil until golden.',
      'Brown ground lamb with onion and garlic until cooked through. Add crushed tomatoes, cinnamon, allspice, and red wine. Simmer 15 minutes.',
      'Make béchamel: melt butter, whisk in flour, gradually add warm milk until thick and smooth. Off heat, whisk in egg and Parmesan.',
      'Layer half the eggplant in a greased baking dish, top with all the meat sauce, then remaining eggplant.',
      'Pour béchamel over the top and smooth evenly.',
      'Bake at 375°F for 40–45 minutes until béchamel is golden and set.',
      'Rest 15 minutes before slicing and serving.'
    ],
    'greek', true, 420, 24, 28, 26, 'any', ARRAY['Nut-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000027.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'eggplant', '2 large, sliced'),
    (recipe_id, 'used', 'ground lamb', '500g'),
    (recipe_id, 'used', 'onion', '1, diced'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'crushed tomatoes', '400g'),
    (recipe_id, 'used', 'red wine', '1/4 cup'),
    (recipe_id, 'used', 'cinnamon', '1/2 tsp'),
    (recipe_id, 'used', 'allspice', '1/4 tsp'),
    (recipe_id, 'used', 'butter', '3 tbsp'),
    (recipe_id, 'used', 'flour', '3 tbsp'),
    (recipe_id, 'used', 'milk', '2 cups, warm'),
    (recipe_id, 'used', 'egg', '1'),
    (recipe_id, 'used', 'Parmesan', '1/2 cup, grated');
END $$;

-- ─── Recipe 28: Vegan Falafel Wrap ───────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000028';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Vegan Falafel Wrap',
    'Crispy herb-packed chickpea fritters wrapped in warm pita with tahini, cucumber, and tomato.',
    40, 4,
    ARRAY[
      'Drain and dry canned chickpeas thoroughly (excess moisture causes dense falafel).',
      'Pulse chickpeas, parsley, cilantro, garlic, cumin, coriander, and salt in a food processor until a coarse, moldable dough forms. Do not over-blend.',
      'Stir in flour. Refrigerate mixture 15 minutes.',
      'Form into small patties. Shallow-fry in 1cm of oil over medium-high heat until deep golden, 2–3 minutes per side.',
      'Whisk tahini with lemon juice, garlic, and water until smooth and pourable.',
      'Warm pita breads briefly in a dry pan.',
      'Spread tahini inside pita, add falafel, sliced cucumber, tomato, red onion, and fresh herbs.'
    ],
    'mediterranean', true, 420, 14, 56, 16, 'vegan', ARRAY['Dairy-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000028.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chickpeas', '2 cans, drained and dried'),
    (recipe_id, 'used', 'fresh parsley', '1/2 cup'),
    (recipe_id, 'used', 'fresh cilantro', '1/2 cup'),
    (recipe_id, 'used', 'garlic', '4 cloves'),
    (recipe_id, 'used', 'cumin', '1.5 tsp'),
    (recipe_id, 'used', 'coriander', '1 tsp'),
    (recipe_id, 'used', 'flour', '2 tbsp'),
    (recipe_id, 'used', 'pita bread', '4'),
    (recipe_id, 'used', 'tahini', '4 tbsp'),
    (recipe_id, 'used', 'lemon juice', '2 tbsp'),
    (recipe_id, 'used', 'cucumber', '1, sliced'),
    (recipe_id, 'used', 'tomatoes', '2, sliced'),
    (recipe_id, 'used', 'red onion', '1/2, thinly sliced');
END $$;

-- ─── Recipe 29: Birria Tacos ──────────────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000029';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Birria Tacos',
    'Slow-braised chili beef tacos dipped in rich consommé — crispy, juicy, and deeply flavoured.',
    180, 6,
    ARRAY[
      'Toast dried guajillo and ancho chiles in a dry pan 30 seconds, then soak in hot water 20 minutes.',
      'Blend soaked chiles with beef broth, garlic, cumin, oregano, cloves, and cinnamon until smooth.',
      'Season beef chuck with salt and sear in oil until browned on all sides.',
      'Pour chile sauce over beef, add remaining broth, and braise covered at 325°F for 2.5 hours until fork-tender.',
      'Shred beef and strain braising liquid into a bowl (consommé for dipping).',
      'Dip corn tortillas in the consommé fat layer, place on a hot griddle, add cheese and shredded beef, fold and cook until crispy.',
      'Serve tacos with diced onion, cilantro, and a cup of consommé for dipping.'
    ],
    'mexican', true, 410, 32, 28, 18, 'any', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000029.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef chuck', '1 kg, cut into chunks'),
    (recipe_id, 'used', 'dried guajillo chiles', '4, stems removed'),
    (recipe_id, 'used', 'dried ancho chiles', '2, stems removed'),
    (recipe_id, 'used', 'beef broth', '3 cups'),
    (recipe_id, 'used', 'garlic', '6 cloves'),
    (recipe_id, 'used', 'cumin', '1.5 tsp'),
    (recipe_id, 'used', 'dried oregano', '1 tsp'),
    (recipe_id, 'used', 'corn tortillas', '12 small'),
    (recipe_id, 'used', 'Oaxaca or mozzarella cheese', '1 cup, shredded'),
    (recipe_id, 'used', 'white onion', '1, finely diced'),
    (recipe_id, 'used', 'cilantro', '1 cup, chopped'),
    (recipe_id, 'used', 'lime', '2, cut into wedges');
END $$;

-- ─── Recipe 30: Tonkotsu Ramen ───────────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000030';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Tonkotsu Ramen',
    'Creamy, rich pork-bone broth with springy noodles, chashu pork, soft egg, and nori.',
    240, 4,
    ARRAY[
      'Blanch pork bones in boiling water 10 minutes; drain, rinse, and return to a clean pot.',
      'Cover bones with fresh water, add garlic and ginger; boil vigorously uncovered for 3 hours until broth is milky white.',
      'Season broth with soy sauce, mirin, and salt. Strain and keep hot.',
      'For chashu: roll pork belly tightly, tie with twine, sear until browned all over, then braise in soy sauce, mirin, sake, and sugar for 90 minutes. Slice when cool.',
      'Soft-boil eggs 6.5 minutes, then marinate in equal parts soy sauce and mirin for at least 1 hour.',
      'Cook fresh ramen noodles in boiling water 2 minutes; divide into bowls.',
      'Ladle hot broth over noodles, top with chashu slices, halved marinated egg, nori, bamboo shoots, and green onion.'
    ],
    'japanese', true, 560, 28, 62, 22, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000030.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'pork neck bones', '1 kg'),
    (recipe_id, 'used', 'pork belly', '300g'),
    (recipe_id, 'used', 'ramen noodles', '4 portions'),
    (recipe_id, 'used', 'eggs', '4'),
    (recipe_id, 'used', 'soy sauce', '4 tbsp'),
    (recipe_id, 'used', 'mirin', '3 tbsp'),
    (recipe_id, 'used', 'sake', '2 tbsp'),
    (recipe_id, 'used', 'garlic', '4 cloves, smashed'),
    (recipe_id, 'used', 'ginger', '3-inch piece, sliced'),
    (recipe_id, 'used', 'nori sheets', '4'),
    (recipe_id, 'used', 'bamboo shoots', '1/2 cup'),
    (recipe_id, 'used', 'green onions', '3 stalks, sliced');
END $$;

-- ─── Recipe 31: French Onion Soup ────────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000031';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'French Onion Soup',
    'Deeply caramelized onion broth topped with toasted baguette and bubbling gruyère.',
    65, 4,
    ARRAY[
      'Melt butter with olive oil in a heavy pot over medium-low heat. Add sliced onions with a pinch of salt.',
      'Cook onions, stirring every few minutes, for 45 minutes until deeply golden and jammy.',
      'Increase heat, add thyme and bay leaf, and cook 2 minutes. Deglaze with dry white wine; scrape up all browned bits.',
      'Pour in broth, season with salt and pepper, and simmer 15 minutes.',
      'Toast baguette slices under the broiler until golden.',
      'Ladle soup into oven-safe bowls, float 2 baguette slices on top, and pile on grated Gruyère.',
      'Broil bowls 3–4 minutes until cheese is melted and bubbling. Serve immediately.'
    ],
    'french', true, 280, 12, 28, 14, 'vegetarian', ARRAY['Nut-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000031.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'yellow onions', '4 large, thinly sliced'),
    (recipe_id, 'used', 'butter', '4 tbsp'),
    (recipe_id, 'used', 'olive oil', '2 tbsp'),
    (recipe_id, 'used', 'dry white wine', '1/2 cup'),
    (recipe_id, 'used', 'vegetable broth', '6 cups'),
    (recipe_id, 'used', 'fresh thyme', '4 sprigs'),
    (recipe_id, 'used', 'bay leaf', '1'),
    (recipe_id, 'used', 'baguette', '8 slices, toasted'),
    (recipe_id, 'used', 'Gruyère cheese', '2 cups, grated');
END $$;

-- ─── Recipe 32: High-Protein Salmon Bowl ─────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000032';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'High-Protein Salmon Bowl',
    'Seared salmon over brown rice with edamame, avocado, and sesame soy dressing — 46g protein.',
    25, 2,
    ARRAY[
      'Pat salmon fillets dry and season with salt, pepper, and a pinch of garlic powder.',
      'Sear salmon skin-side down in a hot oiled skillet for 4 minutes; flip and cook 2–3 more minutes until just cooked through.',
      'Whisk together soy sauce, sesame oil, rice vinegar, honey, and a squeeze of lime.',
      'Cook edamame from frozen in salted boiling water 3 minutes; drain.',
      'Slice cucumber and avocado. Cook or reheat brown rice.',
      'Build bowls: rice base, salmon, edamame, cucumber, and avocado.',
      'Drizzle dressing over everything and top with sesame seeds and sliced green onion.'
    ],
    'american', true, 520, 46, 34, 18, 'pescatarian', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000032.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'salmon fillets', '400g'),
    (recipe_id, 'used', 'cooked brown rice', '2 cups'),
    (recipe_id, 'used', 'frozen edamame', '1 cup, shelled'),
    (recipe_id, 'used', 'avocado', '1, sliced'),
    (recipe_id, 'used', 'cucumber', '1, sliced'),
    (recipe_id, 'used', 'soy sauce', '2 tbsp'),
    (recipe_id, 'used', 'sesame oil', '1 tbsp'),
    (recipe_id, 'used', 'rice vinegar', '1 tbsp'),
    (recipe_id, 'used', 'honey', '1 tsp'),
    (recipe_id, 'used', 'sesame seeds', '1 tbsp'),
    (recipe_id, 'used', 'green onions', '2 stalks, sliced');
END $$;

-- ─── Recipe 33: Miso Glazed Cod ──────────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000033';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Miso Glazed Cod',
    'Silky cod fillets marinated in sweet white miso and broiled until caramelised — restaurant quality at home.',
    20, 2,
    ARRAY[
      'Whisk together white miso, mirin, sake, and sugar until the sugar dissolves.',
      'Pat cod fillets dry and coat both sides with the miso marinade. Refrigerate at least 30 minutes (up to 24 hours).',
      'Preheat broiler to high. Line a baking sheet with foil and brush lightly with oil.',
      'Wipe excess marinade from fish (it burns easily) and place on prepared sheet.',
      'Broil 5–7 minutes until the surface is deeply caramelised and fish flakes easily.',
      'Plate over steamed rice, garnish with thinly sliced green onion and sesame seeds.',
      'Serve with a lemon wedge and pickled ginger on the side.'
    ],
    'japanese', true, 320, 36, 18, 10, 'pescatarian', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000033.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'cod fillets', '400g'),
    (recipe_id, 'used', 'white miso paste', '3 tbsp'),
    (recipe_id, 'used', 'mirin', '2 tbsp'),
    (recipe_id, 'used', 'sake', '1 tbsp'),
    (recipe_id, 'used', 'sugar', '1 tbsp'),
    (recipe_id, 'used', 'sesame oil', '1 tsp'),
    (recipe_id, 'used', 'green onions', '2 stalks, thinly sliced'),
    (recipe_id, 'used', 'sesame seeds', '1 tsp'),
    (recipe_id, 'used', 'lemon', '1, cut into wedges');
END $$;

-- ─── Recipe 34: Char Siu Pork Rice ───────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000034';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Char Siu Pork Rice',
    'Cantonese BBQ pork glazed with a honey-hoisin sauce, served over steamed rice with blanched bok choy.',
    90, 4,
    ARRAY[
      'Mix hoisin sauce, soy sauce, honey, Chinese 5-spice, garlic, and sesame oil into a marinade.',
      'Slice pork shoulder into thick strips. Coat in marinade and refrigerate at least 2 hours.',
      'Place pork on a rack over a foil-lined tray. Roast at 400°F for 25 minutes.',
      'Brush with reserved marinade, flip, and roast 20 more minutes until edges are caramelised and slightly charred.',
      'Rest 5 minutes then slice diagonally.',
      'Blanch bok choy in boiling salted water for 1 minute; drain.',
      'Serve sliced char siu over steamed jasmine rice with bok choy and a drizzle of the pan juices.'
    ],
    'chinese', true, 480, 28, 52, 16, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000034.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'pork shoulder', '600g, sliced into thick strips'),
    (recipe_id, 'used', 'hoisin sauce', '3 tbsp'),
    (recipe_id, 'used', 'soy sauce', '2 tbsp'),
    (recipe_id, 'used', 'honey', '3 tbsp'),
    (recipe_id, 'used', 'Chinese 5-spice powder', '1 tsp'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'sesame oil', '1 tbsp'),
    (recipe_id, 'used', 'bok choy', '2 heads, halved'),
    (recipe_id, 'used', 'jasmine rice', '3 cups, cooked');
END $$;

-- ─── Recipe 35: Palak Paneer ─────────────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000035';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Palak Paneer',
    'Velvety spiced spinach curry with golden pan-fried paneer — a beloved Indian vegetarian classic.',
    35, 4,
    ARRAY[
      'Blanch spinach in boiling water 1 minute; transfer to ice water. Blend with green chili until smooth.',
      'Pan-fry paneer cubes in butter until golden on all sides; set aside.',
      'In the same pan, heat oil and pop cumin seeds. Add onion and cook until golden, about 8 minutes.',
      'Add garlic and ginger; cook 1 minute. Stir in turmeric, coriander, and garam masala.',
      'Pour in the spinach purée and simmer 5 minutes. Add cream and stir to combine.',
      'Fold in paneer, season with salt, and simmer 3 more minutes.',
      'Serve with warm naan or basmati rice and a squeeze of lemon.'
    ],
    'indian', true, 340, 18, 16, 24, 'vegetarian', ARRAY['Gluten-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000035.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'paneer', '250g, cubed'),
    (recipe_id, 'used', 'fresh spinach', '500g'),
    (recipe_id, 'used', 'onion', '1 large, diced'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'ginger', '1 tbsp, grated'),
    (recipe_id, 'used', 'green chili', '1'),
    (recipe_id, 'used', 'heavy cream', '3 tbsp'),
    (recipe_id, 'used', 'cumin seeds', '1 tsp'),
    (recipe_id, 'used', 'garam masala', '1 tsp'),
    (recipe_id, 'used', 'turmeric', '1/2 tsp'),
    (recipe_id, 'used', 'butter', '2 tbsp');
END $$;

-- ─── Recipe 36: Tom Yum Goong ─────────────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000036';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Tom Yum Goong',
    'Fiery and sour Thai shrimp soup with lemongrass, galangal, and kaffir lime — bold, bright, and warming.',
    25, 4,
    ARRAY[
      'Bruise lemongrass stalks with the back of a knife and slice into 2-inch pieces.',
      'Bring broth to a boil with lemongrass, galangal, and kaffir lime leaves for 5 minutes to infuse.',
      'Add mushrooms and simmer 3 minutes.',
      'Add shrimp and halved cherry tomatoes; cook 2 minutes until shrimp are pink and curled.',
      'Remove from heat. Stir in fish sauce, lime juice, and Thai bird chilies.',
      'Taste and adjust sourness with more lime and saltiness with more fish sauce.',
      'Garnish with fresh cilantro and sliced green onion. Serve immediately with jasmine rice.'
    ],
    'thai', true, 160, 18, 8, 6, 'pescatarian', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Egg-Free'],
    'seeds/a0000001-0000-4000-8000-000000000036.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'large shrimp', '400g, peeled and deveined'),
    (recipe_id, 'used', 'chicken or vegetable broth', '6 cups'),
    (recipe_id, 'used', 'lemongrass', '3 stalks'),
    (recipe_id, 'used', 'galangal or ginger', '4 slices'),
    (recipe_id, 'used', 'kaffir lime leaves', '6'),
    (recipe_id, 'used', 'mushrooms', '200g, halved'),
    (recipe_id, 'used', 'cherry tomatoes', '1 cup, halved'),
    (recipe_id, 'used', 'fish sauce', '3 tbsp'),
    (recipe_id, 'used', 'lime juice', '3 tbsp'),
    (recipe_id, 'used', 'Thai bird chilies', '3, sliced'),
    (recipe_id, 'used', 'cilantro', '1/4 cup');
END $$;

-- ─── Recipe 37: Beef Bourguignon ─────────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000037';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Beef Bourguignon',
    'Slow-braised Burgundy beef with mushrooms, lardons, and pearl onions — the definitive French braise.',
    150, 6,
    ARRAY[
      'Pat beef dry and season with salt. Sear in butter in batches until browned all over; remove from pot.',
      'Fry lardons until crispy; add pearl onions and mushrooms, sauté until golden. Remove and set aside.',
      'Add flour to pot and stir 1 minute. Deglaze with cognac (optional) then add wine, broth, tomato paste, thyme, and bay leaves.',
      'Return beef to pot, bring to a simmer, cover, and braise at 325°F for 2.5 hours until very tender.',
      'Return lardons, onions, and mushrooms to the pot for the final 30 minutes.',
      'Remove thyme sprigs and bay leaves. Skim any fat from the surface.',
      'Serve over egg noodles or mashed potatoes, garnished with fresh parsley.'
    ],
    'french', true, 480, 38, 18, 28, 'any', ARRAY['Nut-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000037.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef chuck', '1 kg, cut into 5cm cubes'),
    (recipe_id, 'used', 'red Burgundy wine', '750ml'),
    (recipe_id, 'used', 'beef broth', '1 cup'),
    (recipe_id, 'used', 'bacon lardons', '150g'),
    (recipe_id, 'used', 'pearl onions', '18, peeled'),
    (recipe_id, 'used', 'cremini mushrooms', '300g, quartered'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'tomato paste', '1 tbsp'),
    (recipe_id, 'used', 'flour', '2 tbsp'),
    (recipe_id, 'used', 'fresh thyme', '4 sprigs'),
    (recipe_id, 'used', 'bay leaves', '2'),
    (recipe_id, 'used', 'butter', '3 tbsp');
END $$;

-- ─── Recipe 38: Vegan Red Lentil Dal ─────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000038';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Vegan Red Lentil Dal',
    'Creamy coconut red lentil dal spiced with turmeric and cumin — hearty, cheap, and ready in 35 minutes.',
    35, 4,
    ARRAY[
      'Rinse red lentils until the water runs clear.',
      'Heat oil in a large pot over medium heat. Pop cumin seeds until fragrant.',
      'Add diced onion and cook 8 minutes until golden. Add garlic and ginger, cook 1 minute.',
      'Stir in turmeric, garam masala, and coriander; toast 30 seconds.',
      'Add crushed tomatoes and cook 5 minutes. Pour in coconut milk and 1 cup water.',
      'Add lentils, bring to a gentle boil, then simmer uncovered 20 minutes until lentils are soft and creamy.',
      'Season with salt and lemon juice. Serve with rice or naan, garnished with fresh cilantro and a swirl of coconut milk.'
    ],
    'indian', true, 280, 14, 42, 6, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000038.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'red lentils', '2 cups, rinsed'),
    (recipe_id, 'used', 'coconut milk', '400ml'),
    (recipe_id, 'used', 'crushed tomatoes', '400g'),
    (recipe_id, 'used', 'onion', '1 large, diced'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'ginger', '1 tbsp, grated'),
    (recipe_id, 'used', 'cumin seeds', '1 tsp'),
    (recipe_id, 'used', 'turmeric', '1 tsp'),
    (recipe_id, 'used', 'garam masala', '1.5 tsp'),
    (recipe_id, 'used', 'ground coriander', '1 tsp'),
    (recipe_id, 'used', 'vegetable oil', '2 tbsp'),
    (recipe_id, 'used', 'lemon juice', '1 tbsp'),
    (recipe_id, 'used', 'cilantro', 'for garnish');
END $$;

-- ─── Recipe 39: Spanish Seafood Paella ───────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000039';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Spanish Seafood Paella',
    'Authentic Valencian rice with shrimp, mussels, and squid — finished with a prized socarrat crust.',
    50, 4,
    ARRAY[
      'Warm saffron threads in 1/4 cup hot broth; set aside to bloom.',
      'Heat olive oil in a wide paella pan. Sauté onion and red pepper until soft.',
      'Add garlic and smoked paprika; cook 30 seconds. Add grated tomatoes and cook down 5 minutes.',
      'Add rice and stir to coat in the sofrito. Pour in all the broth including saffron-infused broth.',
      'Spread rice evenly and do not stir again. Simmer on medium heat 10 minutes.',
      'Nestle shrimp, mussels, and squid rings into the rice. Cook 8–10 more minutes until seafood is cooked and rice has absorbed all liquid.',
      'Increase heat for 1–2 minutes at the end to develop the socarrat (golden crust on the bottom). Let rest 5 minutes and serve with lemon wedges.'
    ],
    'spanish', true, 420, 28, 52, 10, 'pescatarian', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Egg-Free'],
    'seeds/a0000001-0000-4000-8000-000000000039.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'bomba or Arborio rice', '2 cups'),
    (recipe_id, 'used', 'shrimp', '200g, peeled'),
    (recipe_id, 'used', 'mussels', '300g, scrubbed'),
    (recipe_id, 'used', 'squid', '200g, cleaned and sliced'),
    (recipe_id, 'used', 'fish or chicken broth', '4 cups'),
    (recipe_id, 'used', 'onion', '1, diced'),
    (recipe_id, 'used', 'red bell pepper', '1, diced'),
    (recipe_id, 'used', 'garlic', '4 cloves, minced'),
    (recipe_id, 'used', 'canned crushed tomatoes', '1/2 cup'),
    (recipe_id, 'used', 'saffron threads', '1/2 tsp'),
    (recipe_id, 'used', 'smoked paprika', '1 tsp'),
    (recipe_id, 'used', 'olive oil', '3 tbsp'),
    (recipe_id, 'used', 'lemon', '1, cut into wedges');
END $$;

-- ─── Recipe 40: Açaí Smoothie Bowl ───────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000040';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Açaí Smoothie Bowl',
    'Thick, vibrant açaí blended with banana and berries, topped with granola, fresh fruit, and seeds.',
    10, 1,
    ARRAY[
      'Slightly thaw frozen açaí packets by running under cold water for 30 seconds.',
      'Break açaí into pieces and blend with frozen banana, frozen mixed berries, and coconut milk.',
      'Blend on high until completely smooth and thick — the consistency should be thicker than a smoothie.',
      'Pour into a chilled bowl.',
      'Top with granola, sliced fresh banana, fresh strawberries, and blueberries.',
      'Sprinkle chia seeds and shredded coconut over the top.',
      'Drizzle with honey or agave and serve immediately.'
    ],
    'other', true, 320, 6, 52, 10, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Egg-Free', 'Shellfish-Free'],
    'seeds/a0000001-0000-4000-8000-000000000040.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'frozen açaí packets', '2 (100g each)'),
    (recipe_id, 'used', 'frozen banana', '1 large'),
    (recipe_id, 'used', 'frozen mixed berries', '1/2 cup'),
    (recipe_id, 'used', 'coconut milk', '1/4 cup'),
    (recipe_id, 'used', 'granola', '1/4 cup'),
    (recipe_id, 'used', 'fresh strawberries', '4, sliced'),
    (recipe_id, 'used', 'fresh blueberries', '1/4 cup'),
    (recipe_id, 'used', 'banana', '1/2, sliced'),
    (recipe_id, 'used', 'chia seeds', '1 tbsp'),
    (recipe_id, 'used', 'shredded coconut', '2 tbsp'),
    (recipe_id, 'used', 'honey or agave', '1 tbsp');
END $$;

