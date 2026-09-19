-- ============================================================
-- UseUp — Seed 20 Ethiopian Recipes (IDs 81–100)
-- ============================================================

-- ─── Recipe 81: Doro Wat ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000081';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Doro Wat',
    'A slow-simmered berbere chicken stew deepened with caramelized onions and finished with a hard-boiled egg for Ethiopia''s most iconic centerpiece dish.',
    90, 4,
    ARRAY[
      'Cook the diced onions in a dry pot over medium heat, stirring often, until they soften and turn deep golden, about 20 minutes.',
      'Stir in the niter kibbeh and cook for 2 minutes before adding the berbere paste, garlic, and ginger, stirring constantly to keep it from scorching.',
      'Pour in a splash of water and simmer the spiced onion base for 10 minutes, adding more water as needed to keep it saucy.',
      'Add the chicken thighs, season with salt, and turn the pieces to coat them fully in the sauce.',
      'Cover and simmer over low heat for 35 to 40 minutes, stirring occasionally, until the chicken is fork-tender and the sauce has thickened.',
      'Nestle the peeled hard-boiled eggs into the stew during the last 10 minutes so they can soak up the sauce.',
      'Taste and adjust the salt and lemon juice, then rest the stew for 5 minutes before serving.'
    ],
    'ethiopian', true, 420, 32, 14, 27, 'any', ARRAY['Gluten-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/doro-wat.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chicken thighs, bone-in', '900g'),
    (recipe_id, 'used', 'red onion, finely diced', '4 large'),
    (recipe_id, 'used', 'berbere spice paste', '4 tbsp'),
    (recipe_id, 'used', 'niter kibbeh (spiced butter)', '3 tbsp'),
    (recipe_id, 'used', 'garlic, minced', '4 cloves'),
    (recipe_id, 'used', 'ginger, grated', '1 tbsp'),
    (recipe_id, 'used', 'hard-boiled eggs', '4'),
    (recipe_id, 'used', 'lemon juice', '1 tbsp'),
    (recipe_id, 'used', 'salt', 'to taste');
END $$;

-- ─── Recipe 82: Misir Wat ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000082';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Misir Wat',
    'Split red lentils simmered in a smoky berbere-spiced onion sauce until velvety, a staple of Ethiopia''s fasting table.',
    45, 4,
    ARRAY[
      'Rinse the split red lentils until the water runs clear and set aside to drain.',
      'Sauté the diced onions in vegetable oil over medium heat until soft and translucent, about 8 minutes.',
      'Stir in the garlic, ginger, and berbere spice, cooking for another minute until fragrant.',
      'Add the tomato paste and cook for 2 minutes to deepen its color.',
      'Pour in the lentils and enough water to cover by an inch, then bring to a simmer.',
      'Cook uncovered, stirring occasionally, for 20 to 25 minutes until the lentils break down into a thick stew.',
      'Season with salt and adjust the consistency with a little extra water if it becomes too thick.'
    ],
    'ethiopian', true, 310, 17, 46, 8, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/misir-wat.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'red split lentils', '300g'),
    (recipe_id, 'used', 'red onion, diced', '2 large'),
    (recipe_id, 'used', 'garlic, minced', '3 cloves'),
    (recipe_id, 'used', 'ginger, grated', '1 tsp'),
    (recipe_id, 'used', 'berbere spice', '3 tbsp'),
    (recipe_id, 'used', 'tomato paste', '2 tbsp'),
    (recipe_id, 'used', 'vegetable oil', '3 tbsp'),
    (recipe_id, 'used', 'salt', 'to taste'),
    (recipe_id, 'used', 'water', '4 cups');
END $$;

-- ─── Recipe 83: Kitfo ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000083';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Kitfo',
    'Finely minced raw beef warmed gently in spiced butter and mitmita, served the traditional Gurage way with fresh cheese and greens.',
    25, 3,
    ARRAY[
      'Trim the beef of all sinew and finely mince it by hand with a sharp knife until almost paste-like.',
      'Warm the niter kibbeh in a small pan over low heat until melted and fragrant, then remove from heat.',
      'In a bowl, combine the minced beef with the mitmita, ground cardamom, and a pinch of salt.',
      'Pour in the warm spiced butter and mix thoroughly, gently warming the beef through without fully cooking it (leb leb style).',
      'Mound the seasoned beef on a plate and crumble the fresh ayib cheese alongside it.',
      'Serve immediately with a side of sautéed gomen and warm injera.'
    ],
    'ethiopian', true, 480, 34, 3, 37, 'any', ARRAY['Gluten-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/kitfo.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef tenderloin, finely minced', '500g'),
    (recipe_id, 'used', 'niter kibbeh (spiced butter)', '4 tbsp'),
    (recipe_id, 'used', 'mitmita spice', '1 tbsp'),
    (recipe_id, 'used', 'ground cardamom', '1/4 tsp'),
    (recipe_id, 'used', 'ayib cheese', '150g'),
    (recipe_id, 'used', 'salt', 'to taste'),
    (recipe_id, 'used', 'sautéed gomen, for serving', '1 cup');
END $$;

-- ─── Recipe 84: Zilzil Tibs ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000084';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Zilzil Tibs',
    'Thin strips of beef seared hard and fast with onion, jalapeño, and rosemary for a smoky, restaurant-style tibs plate.',
    30, 3,
    ARRAY[
      'Slice the beef against the grain into thin strips about the width of a pencil.',
      'Heat the vegetable oil in a wide skillet or wok until just smoking.',
      'Sear the beef strips in batches over high heat for 1 to 2 minutes per side, then set aside.',
      'In the same pan, sauté the sliced onion, garlic, and jalapeño until the onion begins to char at the edges.',
      'Return the beef to the pan along with the rosemary and berbere, tossing everything over high heat for 2 minutes.',
      'Finish with a squeeze of lemon juice and toss once more before plating.'
    ],
    'ethiopian', true, 390, 33, 8, 25, 'any', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/zilzil-tibs.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef sirloin', '500g'),
    (recipe_id, 'used', 'red onion, sliced', '1 large'),
    (recipe_id, 'used', 'garlic, minced', '3 cloves'),
    (recipe_id, 'used', 'jalapeño, sliced', '2'),
    (recipe_id, 'used', 'fresh rosemary, chopped', '1 tbsp'),
    (recipe_id, 'used', 'berbere spice', '1 tbsp'),
    (recipe_id, 'used', 'vegetable oil', '3 tbsp'),
    (recipe_id, 'used', 'lemon juice', '1 tbsp');
END $$;

-- ─── Recipe 85: Shiro Wat ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000085';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Shiro Wat',
    'A creamy chickpea flour stew whisked to silky perfection with garlic, tomato, and berbere, ready in under half an hour.',
    30, 4,
    ARRAY[
      'Sauté the diced onion in vegetable oil over medium heat until soft and golden, about 8 minutes.',
      'Stir in the garlic, ginger, and berbere spice and cook for 1 minute until fragrant.',
      'Add the chopped tomato and cook until it breaks down into a thick sauce, about 5 minutes.',
      'Pour in 3 cups of water and bring to a gentle simmer.',
      'Whisk in the shiro powder in a steady stream, stirring constantly to prevent lumps.',
      'Simmer for 10 to 12 minutes, whisking often, until the stew thickens to a smooth, pourable consistency.',
      'Season with salt and serve immediately while hot, as shiro thickens quickly as it cools.'
    ],
    'ethiopian', true, 260, 13, 32, 9, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/shiro-wat.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'shiro powder (spiced chickpea flour)', '200g'),
    (recipe_id, 'used', 'onion, diced', '1 large'),
    (recipe_id, 'used', 'garlic, minced', '3 cloves'),
    (recipe_id, 'used', 'ginger, grated', '1 tsp'),
    (recipe_id, 'used', 'tomato, chopped', '1 medium'),
    (recipe_id, 'used', 'berbere spice', '1 tbsp'),
    (recipe_id, 'used', 'vegetable oil', '3 tbsp'),
    (recipe_id, 'used', 'water', '3 cups'),
    (recipe_id, 'used', 'salt', 'to taste');
END $$;

-- ─── Recipe 86: Gomen ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000086';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Gomen',
    'Ethiopian collard greens braised low and slow with garlic, ginger, and jalapeño until tender and deeply savory.',
    40, 4,
    ARRAY[
      'Wash the collard greens thoroughly and slice them into thin ribbons, discarding any tough stems.',
      'Heat the vegetable oil in a large pot and sauté the onion until soft and translucent.',
      'Add the garlic, ginger, and jalapeño, cooking for another minute until fragrant.',
      'Stir in the sliced collard greens a handful at a time, letting each batch wilt before adding more.',
      'Pour in a splash of water, cover, and cook over low heat for 25 to 30 minutes, stirring occasionally, until the greens are silky and tender.',
      'Season with salt and a squeeze of lemon juice before serving warm.'
    ],
    'ethiopian', true, 140, 5, 12, 9, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/gomen.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'collard greens, chopped', '1 large bunch'),
    (recipe_id, 'used', 'onion, diced', '1 medium'),
    (recipe_id, 'used', 'garlic, minced', '3 cloves'),
    (recipe_id, 'used', 'ginger, grated', '1 tsp'),
    (recipe_id, 'used', 'jalapeño, minced', '1'),
    (recipe_id, 'used', 'vegetable oil', '3 tbsp'),
    (recipe_id, 'used', 'lemon juice', '1 tsp'),
    (recipe_id, 'used', 'salt', 'to taste');
END $$;

-- ─── Recipe 87: Yebeg Wat ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000087';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Yebeg Wat',
    'Tender lamb simmered for hours in a fiery berbere sauce until it falls apart at the touch of an injera scoop.',
    110, 4,
    ARRAY[
      'Cook the diced onions in a dry pot over medium heat, stirring frequently, until deeply golden, about 15 minutes.',
      'Stir in the niter kibbeh, then the berbere, garlic, and ginger, cooking for 2 minutes until aromatic.',
      'Add the lamb shoulder pieces and stir to coat them evenly in the spiced onion base.',
      'Pour in enough water to just cover the lamb and bring to a simmer.',
      'Cover and cook over low heat for 75 to 90 minutes, stirring occasionally, until the lamb is fork-tender.',
      'Uncover for the last 15 minutes to let the sauce reduce and thicken.',
      'Season with salt and a squeeze of lemon juice before serving hot.'
    ],
    'ethiopian', true, 460, 36, 10, 30, 'any', ARRAY['Gluten-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/yebeg-wat.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'lamb shoulder, cubed', '900g'),
    (recipe_id, 'used', 'red onion, diced', '3 large'),
    (recipe_id, 'used', 'berbere spice', '3 tbsp'),
    (recipe_id, 'used', 'niter kibbeh (spiced butter)', '3 tbsp'),
    (recipe_id, 'used', 'garlic, minced', '4 cloves'),
    (recipe_id, 'used', 'ginger, grated', '1 tbsp'),
    (recipe_id, 'used', 'lemon juice', '1 tbsp'),
    (recipe_id, 'used', 'salt', 'to taste'),
    (recipe_id, 'used', 'water', '2 cups');
END $$;

-- ─── Recipe 88: Atkilt Alicha ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000088';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Atkilt Alicha',
    'A gently turmeric-spiced medley of cabbage, carrots, and potatoes simmered until tender for a comforting, mild side.',
    35, 4,
    ARRAY[
      'Heat the vegetable oil in a large pot and sauté the onion until soft and translucent.',
      'Stir in the garlic, ginger, and turmeric, cooking for 1 minute until fragrant and golden.',
      'Add the diced potatoes and carrots, tossing to coat them in the spiced oil.',
      'Pour in enough water to come halfway up the vegetables, cover, and simmer for 12 minutes.',
      'Add the shredded cabbage and jalapeño, then cover again and cook for another 10 to 12 minutes until all the vegetables are tender.',
      'Uncover and cook for a few more minutes to let excess liquid evaporate.',
      'Season with salt and finish with a squeeze of lemon juice before serving.'
    ],
    'ethiopian', true, 190, 4, 30, 7, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/atkilt-alicha.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'green cabbage, shredded', 'half head'),
    (recipe_id, 'used', 'potatoes, diced', '2 medium'),
    (recipe_id, 'used', 'carrots, sliced', '2 medium'),
    (recipe_id, 'used', 'onion, diced', '1 medium'),
    (recipe_id, 'used', 'garlic, minced', '2 cloves'),
    (recipe_id, 'used', 'ginger, grated', '1 tsp'),
    (recipe_id, 'used', 'turmeric', '1 tsp'),
    (recipe_id, 'used', 'jalapeño, sliced', '1'),
    (recipe_id, 'used', 'vegetable oil', '3 tbsp'),
    (recipe_id, 'used', 'lemon juice', '1 tsp');
END $$;

-- ─── Recipe 89: Beyaynetu ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000089';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Beyaynetu',
    'A vibrant vegan sampler platter bringing together lentils, split peas, greens, and spiced cabbage arranged for sharing.',
    75, 4,
    ARRAY[
      'Prepare the misir wat by simmering split red lentils with berbere, onion, and garlic until thick, about 20 minutes.',
      'In a separate pot, cook the yellow split peas with turmeric, onion, and ginger until soft and creamy, about 25 minutes.',
      'Braise the collard greens with garlic and a splash of water until tender, about 20 minutes.',
      'Simmer the shredded cabbage, carrots, and potato with turmeric and onion until just tender, about 15 minutes.',
      'Whisk the shiro powder into a small pot of simmering spiced water until smooth and thick.',
      'Arrange each stew in its own mound on a large shared platter.',
      'Serve with warm injera or flatbread of choice on the side for scooping.'
    ],
    'ethiopian', true, 520, 22, 78, 15, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/beyaynetu.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'red split lentils', '150g'),
    (recipe_id, 'used', 'yellow split peas', '150g'),
    (recipe_id, 'used', 'collard greens, chopped', '2 cups'),
    (recipe_id, 'used', 'cabbage, shredded', '2 cups'),
    (recipe_id, 'used', 'carrot, sliced', '1 medium'),
    (recipe_id, 'used', 'potato, diced', '1 medium'),
    (recipe_id, 'used', 'shiro powder', '100g'),
    (recipe_id, 'used', 'berbere spice', '2 tbsp'),
    (recipe_id, 'used', 'onion, diced', '2 medium'),
    (recipe_id, 'used', 'garlic, minced', '3 cloves');
END $$;

-- ─── Recipe 90: Dulet ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000090';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Dulet',
    'A punchy Gurage specialty of minced tripe, liver, and beef sautéed with jalapeño and spiced butter until deeply savory.',
    45, 4,
    ARRAY[
      'Finely dice the tripe, liver, and beef into small, even pieces, or pulse briefly in a food processor for a coarser mince.',
      'Melt the niter kibbeh in a large skillet over medium heat.',
      'Add the diced onion and jalapeño, cooking until softened, about 5 minutes.',
      'Stir in the garlic and ginger, cooking for 1 minute until fragrant.',
      'Add the tripe and cook, stirring frequently, for 10 minutes until it begins to firm up.',
      'Add the liver and beef, along with the mitmita and berbere, and cook for another 12 to 15 minutes until everything is well browned and cooked through.',
      'Season with salt and serve hot, straight from the skillet, with injera on the side.'
    ],
    'ethiopian', true, 410, 30, 5, 30, 'any', ARRAY['Gluten-Free', 'Nut-Free', 'Shellfish-Free'],
    NULL);
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef tripe, finely diced', '200g'),
    (recipe_id, 'used', 'beef liver, finely diced', '200g'),
    (recipe_id, 'used', 'beef, finely diced', '200g'),
    (recipe_id, 'used', 'onion, diced', '1 large'),
    (recipe_id, 'used', 'jalapeño, minced', '2'),
    (recipe_id, 'used', 'garlic, minced', '3 cloves'),
    (recipe_id, 'used', 'ginger, grated', '1 tsp'),
    (recipe_id, 'used', 'niter kibbeh (spiced butter)', '3 tbsp'),
    (recipe_id, 'used', 'mitmita spice', '1 tsp'),
    (recipe_id, 'used', 'berbere spice', '1 tbsp');
END $$;

-- ─── Recipe 91: Kikil ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000091';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Kikil',
    'Lamb shanks gently simmered in a light garlic-and-lemon broth until the meat slips easily from the bone.',
    120, 4,
    ARRAY[
      'Season the lamb shanks generously with salt and set aside for 15 minutes.',
      'Heat the vegetable oil in a large pot and sear the shanks on all sides until browned, about 8 minutes total.',
      'Add the sliced onion, garlic, and ginger, cooking until the onion softens.',
      'Pour in enough water to just cover the shanks and bring to a boil.',
      'Reduce the heat to low, cover, and simmer gently for 90 minutes to 2 hours until the meat is falling-off-the-bone tender.',
      'Stir in the jalapeño and cook uncovered for another 10 minutes to lightly reduce the broth.',
      'Finish with lemon juice and adjust the salt before serving the shanks in shallow bowls with their broth.'
    ],
    'ethiopian', true, 380, 40, 4, 22, 'any', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    NULL);
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'lamb shanks', '4 (about 1.2kg)'),
    (recipe_id, 'used', 'onion, sliced', '1 large'),
    (recipe_id, 'used', 'garlic, minced', '4 cloves'),
    (recipe_id, 'used', 'ginger, sliced', '1 tbsp'),
    (recipe_id, 'used', 'jalapeño, sliced', '1'),
    (recipe_id, 'used', 'vegetable oil', '2 tbsp'),
    (recipe_id, 'used', 'lemon juice', '2 tbsp'),
    (recipe_id, 'used', 'salt', 'to taste'),
    (recipe_id, 'used', 'water', '4 cups');
END $$;

-- ─── Recipe 92: Fosolia ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000092';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Fosolia',
    'Green beans and carrots sautéed with onion, garlic, and a touch of rosemary for a bright, everyday side dish.',
    25, 4,
    ARRAY[
      'Trim the green beans and slice the carrots into thin matchsticks.',
      'Heat the vegetable oil in a wide skillet over medium heat and sauté the onion until translucent.',
      'Add the garlic and cook for 30 seconds until fragrant.',
      'Stir in the carrots and cook for 3 minutes to soften slightly.',
      'Add the green beans along with a splash of water, cover, and cook for 10 to 12 minutes, stirring occasionally, until crisp-tender.',
      'Uncover, stir in the rosemary, and cook for another 2 minutes to evaporate any remaining liquid.',
      'Season with salt and pepper and serve warm.'
    ],
    'ethiopian', true, 120, 3, 14, 6, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    NULL);
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'green beans, trimmed', '400g'),
    (recipe_id, 'used', 'carrots, julienned', '2 medium'),
    (recipe_id, 'used', 'onion, sliced', '1 medium'),
    (recipe_id, 'used', 'garlic, minced', '2 cloves'),
    (recipe_id, 'used', 'fresh rosemary, chopped', '1 tsp'),
    (recipe_id, 'used', 'vegetable oil', '2 tbsp'),
    (recipe_id, 'used', 'salt', 'to taste'),
    (recipe_id, 'used', 'black pepper', 'to taste');
END $$;

-- ─── Recipe 93: Ayib Begomen ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000093';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Ayib Begomen',
    'Soft, crumbled Ethiopian fresh cheese folded into braised collard greens for a cooling, protein-rich pairing.',
    35, 4,
    ARRAY[
      'Wash the collard greens and slice them into thin ribbons.',
      'Heat the vegetable oil in a pot and sauté the onion until soft and translucent.',
      'Add the garlic and ginger, cooking for 1 minute until fragrant.',
      'Stir in the collard greens a handful at a time, allowing each batch to wilt before adding more.',
      'Add a splash of water, cover, and simmer over low heat for 20 to 25 minutes until the greens are tender.',
      'Remove from the heat and gently fold in the crumbled ayib cheese, letting it warm through without melting completely.',
      'Season with salt and serve warm alongside injera.'
    ],
    'ethiopian', true, 210, 12, 9, 14, 'vegetarian', ARRAY['Gluten-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/ayib-begomen.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'collard greens, chopped', '1 large bunch'),
    (recipe_id, 'used', 'ayib cheese, crumbled', '250g'),
    (recipe_id, 'used', 'onion, diced', '1 medium'),
    (recipe_id, 'used', 'garlic, minced', '2 cloves'),
    (recipe_id, 'used', 'ginger, grated', '1 tsp'),
    (recipe_id, 'used', 'vegetable oil', '2 tbsp'),
    (recipe_id, 'used', 'salt', 'to taste');
END $$;

-- ─── Recipe 94: Doro Alicha ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000094';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Doro Alicha',
    'A milder cousin of doro wat, this golden turmeric chicken stew is fragrant with ginger and garlic rather than fiery berbere.',
    75, 4,
    ARRAY[
      'Cook the diced onions in a dry pot over medium heat until soft and lightly golden, about 12 minutes.',
      'Stir in the niter kibbeh, then add the garlic, ginger, and turmeric, cooking for 2 minutes until fragrant.',
      'Add the chicken pieces and turn them to coat evenly in the spiced onion base.',
      'Pour in enough water to come partway up the chicken, cover, and simmer over low heat for 35 to 40 minutes.',
      'Nestle the peeled hard-boiled eggs into the stew for the last 10 minutes so they absorb the sauce.',
      'Uncover and simmer for a few more minutes to let the sauce thicken slightly.',
      'Season with salt and a squeeze of lemon juice before serving.'
    ],
    'ethiopian', true, 400, 33, 8, 25, 'any', ARRAY['Gluten-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/doro-alicha.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chicken thighs, bone-in', '900g'),
    (recipe_id, 'used', 'onion, diced', '3 large'),
    (recipe_id, 'used', 'niter kibbeh (spiced butter)', '3 tbsp'),
    (recipe_id, 'used', 'garlic, minced', '3 cloves'),
    (recipe_id, 'used', 'ginger, grated', '1 tbsp'),
    (recipe_id, 'used', 'turmeric', '1 tsp'),
    (recipe_id, 'used', 'hard-boiled eggs', '4'),
    (recipe_id, 'used', 'lemon juice', '1 tbsp'),
    (recipe_id, 'used', 'salt', 'to taste');
END $$;

-- ─── Recipe 95: Azifa ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000095';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Azifa',
    'A refreshing chilled green lentil salad tossed with mustard, lime, and jalapeño, traditionally served during fasting periods.',
    35, 4,
    ARRAY[
      'Rinse the green lentils and cook them in plenty of water until just tender but not mushy, about 20 minutes.',
      'Drain the lentils and spread them on a tray to cool completely.',
      'Whisk together the mustard powder, lime juice, and a splash of water to form a smooth dressing.',
      'Once the lentils are cool, toss them with the diced red onion, jalapeño, and chopped tomato.',
      'Pour the mustard dressing over the salad and toss well to coat every lentil.',
      'Stir in the chopped cilantro and season with salt to taste.',
      'Chill for at least 15 minutes before serving to let the flavors meld.'
    ],
    'ethiopian', true, 220, 13, 34, 4, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    NULL);
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'green lentils', '250g'),
    (recipe_id, 'used', 'red onion, diced', '1 small'),
    (recipe_id, 'used', 'jalapeño, minced', '1'),
    (recipe_id, 'used', 'tomato, diced', '1 small'),
    (recipe_id, 'used', 'mustard powder', '1 tbsp'),
    (recipe_id, 'used', 'lime juice', '3 tbsp'),
    (recipe_id, 'used', 'cilantro, chopped', '3 tbsp'),
    (recipe_id, 'used', 'salt', 'to taste');
END $$;

-- ─── Recipe 96: Gored Gored ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000096';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Gored Gored',
    'Cubes of tender raw or lightly seared beef tossed in warm spiced butter and mitmita for a bold, minimalist classic.',
    20, 3,
    ARRAY[
      'Trim the beef tenderloin of any silver skin and cut it into small, even cubes.',
      'Melt the niter kibbeh in a small saucepan over low heat until fragrant, then remove from the heat.',
      'If searing, quickly sear the beef cubes in a hot, dry pan for 30 to 45 seconds total, just to color the outside.',
      'Place the beef cubes in a serving bowl and pour the warm spiced butter over the top.',
      'Sprinkle with mitmita and black pepper, tossing gently to coat every piece.',
      'Serve immediately with sliced green chili and extra awaze sauce on the side for dipping.'
    ],
    'ethiopian', true, 430, 30, 1, 34, 'any', ARRAY['Gluten-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/gored-gored.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef tenderloin, cubed', '500g'),
    (recipe_id, 'used', 'niter kibbeh (spiced butter)', '4 tbsp'),
    (recipe_id, 'used', 'mitmita spice', '1 tbsp'),
    (recipe_id, 'used', 'awaze sauce, for serving', '2 tbsp'),
    (recipe_id, 'used', 'fresh green chili, sliced', '1'),
    (recipe_id, 'used', 'black pepper', 'to taste'),
    (recipe_id, 'used', 'salt', 'to taste');
END $$;

-- ─── Recipe 97: Genfo ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000097';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Genfo',
    'A stout barley porridge mounded into a volcano shape with a molten well of berbere butter at its center, Ethiopia''s hearty breakfast classic.',
    30, 4,
    ARRAY[
      'Bring the water to a boil in a heavy-bottomed pot with a pinch of salt.',
      'Reduce the heat to low and slowly whisk in the barley flour in a steady stream to avoid lumps.',
      'Switch to a wooden spoon and stir vigorously and continuously for 10 to 12 minutes until the mixture becomes very thick and pulls away from the sides of the pot.',
      'Wet a wooden spoon or your hands with cold water and shape the porridge into a smooth dome on each plate, pressing a well into the center.',
      'Melt the niter kibbeh with the berbere powder in a small pan until fragrant.',
      'Spoon the spiced butter into the well of each porridge dome.',
      'Add a dollop of plain yogurt on the side and serve immediately while hot.'
    ],
    'ethiopian', true, 340, 8, 52, 11, 'vegetarian', ARRAY['Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/genfo.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'barley flour', '250g'),
    (recipe_id, 'used', 'water', '4 cups'),
    (recipe_id, 'used', 'niter kibbeh (spiced butter)', '3 tbsp'),
    (recipe_id, 'used', 'berbere spice', '1 tbsp'),
    (recipe_id, 'used', 'plain yogurt', '1/2 cup'),
    (recipe_id, 'used', 'salt', 'to taste');
END $$;

-- ─── Recipe 98: Chechebsa ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000098';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Chechebsa',
    'Torn strips of griddle-cooked flatbread tossed in warm berbere butter for a beloved Ethiopian breakfast street food.',
    30, 4,
    ARRAY[
      'Mix the flour, yeast, and a pinch of salt with warm water to form a soft, slightly sticky dough.',
      'Cover and let the dough rest for 15 minutes.',
      'Divide the dough into rounds and press each one flat into a thin disc.',
      'Cook each disc on a hot, dry griddle for 2 to 3 minutes per side until lightly charred and cooked through.',
      'While still warm, tear the flatbreads into bite-sized pieces.',
      'Melt the niter kibbeh with the berbere powder in a small pan until fragrant.',
      'Toss the torn bread pieces in the spiced butter until every piece is well coated, then serve warm.'
    ],
    'ethiopian', true, 380, 8, 48, 17, 'vegetarian', ARRAY['Nut-Free', 'Shellfish-Free'],
    NULL);
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'all-purpose flour', '300g'),
    (recipe_id, 'used', 'active dry yeast', '1 tsp'),
    (recipe_id, 'used', 'warm water', '200ml'),
    (recipe_id, 'used', 'niter kibbeh (spiced butter)', '4 tbsp'),
    (recipe_id, 'used', 'berbere spice', '1 tbsp'),
    (recipe_id, 'used', 'salt', 'to taste');
END $$;

-- ─── Recipe 99: Key Wat ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000099';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Key Wat',
    'A fiery beef stew built on the same slow-cooked berbere base as doro wat, rich, deep red, and deeply comforting.',
    100, 4,
    ARRAY[
      'Cook the diced onions in a dry pot over medium heat, stirring often, until deeply golden, about 18 minutes.',
      'Stir in the niter kibbeh, then the berbere, garlic, and ginger, cooking for 2 minutes until fragrant.',
      'Add the beef stew meat and stir to coat it thoroughly in the spiced onion base.',
      'Pour in enough water to just cover the beef and bring to a simmer.',
      'Cover and cook over low heat for 70 to 80 minutes, stirring occasionally, until the beef is tender.',
      'Uncover for the last 15 minutes to let the sauce reduce to a thick, glossy consistency.',
      'Season with salt and serve hot with injera.'
    ],
    'ethiopian', true, 440, 34, 9, 29, 'any', ARRAY['Gluten-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/key-wat.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef chuck, cubed', '900g'),
    (recipe_id, 'used', 'red onion, diced', '3 large'),
    (recipe_id, 'used', 'berbere spice', '3 tbsp'),
    (recipe_id, 'used', 'niter kibbeh (spiced butter)', '3 tbsp'),
    (recipe_id, 'used', 'garlic, minced', '4 cloves'),
    (recipe_id, 'used', 'ginger, grated', '1 tbsp'),
    (recipe_id, 'used', 'salt', 'to taste'),
    (recipe_id, 'used', 'water', '2 cups');
END $$;

-- ─── Recipe 100: Buticha ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000100';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Buticha',
    'A bright, nutty roasted chickpea flour salad brightened with lime, mustard, and jalapeño, often called Ethiopia''s answer to hummus.',
    20, 4,
    ARRAY[
      'In a bowl, whisk the roasted chickpea flour with warm water a little at a time until a smooth, thick paste forms.',
      'Stir in the mustard powder, lime juice, and olive oil until fully incorporated.',
      'Fold in the finely diced onion, jalapeño, and tomato.',
      'Season with salt and adjust the lime juice or water to reach a creamy, scoopable consistency.',
      'Transfer to a shallow bowl and drizzle with a little extra olive oil.',
      'Garnish with chopped cilantro and serve with injera or fresh vegetables for scooping.'
    ],
    'ethiopian', true, 210, 9, 20, 11, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    NULL);
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'roasted chickpea flour', '200g'),
    (recipe_id, 'used', 'warm water', '150ml'),
    (recipe_id, 'used', 'mustard powder', '1 tsp'),
    (recipe_id, 'used', 'lime juice', '2 tbsp'),
    (recipe_id, 'used', 'olive oil', '2 tbsp'),
    (recipe_id, 'used', 'red onion, diced', '1 small'),
    (recipe_id, 'used', 'jalapeño, minced', '1'),
    (recipe_id, 'used', 'tomato, diced', '1 small'),
    (recipe_id, 'used', 'cilantro, chopped', '2 tbsp'),
    (recipe_id, 'used', 'salt', 'to taste');
END $$;
