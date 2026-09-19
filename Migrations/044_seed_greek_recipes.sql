-- ============================================================
-- UseUp — Seed 20 Greek Recipes (IDs 41–60)
-- ============================================================

-- ─── Recipe 41: Pastitsio ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000041';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Pastitsio',
    'A comforting baked casserole layering tubular pasta and spiced ground beef under a golden nutmeg-scented béchamel.',
    90, 6,
    ARRAY[
      'Cook the tubular pasta in salted boiling water until just shy of al dente, then drain and toss with a beaten egg white to seal the noodles.',
      'Brown the ground beef with the chopped onion in olive oil until no pink remains.',
      'Stir in the crushed tomatoes and ground cinnamon, then simmer uncovered until the sauce has thickened.',
      'Melt the butter in a saucepan, whisk in the flour to form a roux, and gradually add the warm milk, stirring constantly until the béchamel thickens.',
      'Off the heat, whisk two of the eggs and half the grated cheese into the béchamel.',
      'Layer half the pasta in a buttered baking dish, spread the meat sauce over it, top with the remaining pasta, and pour the béchamel evenly over the top.',
      'Sprinkle with the remaining cheese and bake until the top is deeply golden and set.',
      'Let the pastitsio rest for at least fifteen minutes before slicing into squares.'
    ],
    'greek', true, 520, 24, 42, 28, 'any', ARRAY[]::text[],
    '00000000-0000-0000-0000-000000555570/pastitsio.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'ground beef', '500g'),
    (recipe_id, 'used', 'tubular pasta', '400g'),
    (recipe_id, 'used', 'onion', '1, finely chopped'),
    (recipe_id, 'used', 'crushed tomatoes', '400g'),
    (recipe_id, 'used', 'ground cinnamon', '1/2 tsp'),
    (recipe_id, 'used', 'butter', '60g'),
    (recipe_id, 'used', 'flour', '60g'),
    (recipe_id, 'used', 'whole milk', '700ml'),
    (recipe_id, 'used', 'eggs', '3'),
    (recipe_id, 'used', 'grated hard cheese', '150g');
END $$;

-- ─── Recipe 42: Spanakopita Triangles ──────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000042';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Spanakopita Triangles',
    'Crisp golden phyllo triangles packed with garlicky spinach, dill, and tangy feta.',
    60, 6,
    ARRAY[
      'Wilt the spinach in a hot pan in batches, then squeeze out as much liquid as possible once cooled and chop finely.',
      'Sauté the onion and scallions in olive oil until soft.',
      'Combine the spinach, sautéed onions, crumbled feta, dill, and beaten eggs in a large bowl, seasoning with black pepper.',
      'Lay a sheet of phyllo on a clean surface, brush lightly with melted butter, and cut lengthwise into strips.',
      'Place a spoonful of the spinach filling at the base of each strip and fold it up in a triangle, flag-fold style, to the end.',
      'Arrange the triangles seam-side down on a baking sheet and brush the tops with more melted butter.',
      'Bake until the phyllo is crisp and deep golden brown.',
      'Cool slightly on a wire rack before serving warm.'
    ],
    'greek', true, 320, 9, 28, 20, 'vegetarian', ARRAY['Nut-Free'],
    '00000000-0000-0000-0000-000000555570/spanakopita-triangles.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'fresh spinach', '500g'),
    (recipe_id, 'used', 'phyllo dough', '1 package'),
    (recipe_id, 'used', 'feta cheese', '200g, crumbled'),
    (recipe_id, 'used', 'onion', '1, chopped'),
    (recipe_id, 'used', 'scallions', '4, chopped'),
    (recipe_id, 'used', 'fresh dill', '3 tbsp, chopped'),
    (recipe_id, 'used', 'eggs', '2'),
    (recipe_id, 'used', 'butter', '100g, melted'),
    (recipe_id, 'used', 'olive oil', '2 tbsp');
END $$;

-- ─── Recipe 43: Avgolemono Chicken Soup ────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000043';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Avgolemono Chicken Soup',
    'A silky lemon-egg thickened chicken and rice soup that is the ultimate Greek comfort food.',
    45, 4,
    ARRAY[
      'Simmer the chicken thighs in the broth with the onion and carrot until the chicken is cooked through and tender.',
      'Remove the chicken, shred the meat once cool enough to handle, and discard the bones and skin.',
      'Strain the broth back into the pot, bring to a simmer, and stir in the rice, cooking until tender.',
      'Whisk the eggs vigorously in a bowl, then whisk in the lemon juice.',
      'Slowly ladle a cup of the hot broth into the egg-lemon mixture while whisking constantly to temper it.',
      'Pour the tempered mixture back into the pot in a thin stream, stirring constantly, and warm gently without letting it boil.',
      'Return the shredded chicken to the pot and season with salt and pepper.',
      'Ladle into bowls and finish with a scatter of fresh dill.'
    ],
    'greek', true, 310, 22, 28, 12, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/avgolemono-chicken-soup.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'chicken thighs', '500g, bone-in'),
    (recipe_id, 'used', 'chicken broth', '2 liters'),
    (recipe_id, 'used', 'white rice', '100g'),
    (recipe_id, 'used', 'onion', '1, quartered'),
    (recipe_id, 'used', 'carrot', '1, chopped'),
    (recipe_id, 'used', 'eggs', '3'),
    (recipe_id, 'used', 'lemon juice', '80ml'),
    (recipe_id, 'used', 'fresh dill', '2 tbsp, chopped');
END $$;

-- ─── Recipe 44: Gemista Stuffed Tomatoes and Peppers ───────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000044';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Gemista Stuffed Tomatoes and Peppers',
    'Sweet tomatoes and bell peppers hollowed out and baked with a fragrant herbed rice filling.',
    90, 6,
    ARRAY[
      'Slice the tops off the tomatoes and peppers, scoop out the flesh and seeds, and reserve the tomato pulp.',
      'Sauté the onion in olive oil until translucent, then add the rice and toast briefly.',
      'Stir in the reserved tomato pulp, chopped herbs, and a splash of water, and cook until the rice is half-cooked.',
      'Season the rice mixture with salt, pepper, and a pinch of sugar, then spoon it into the hollowed vegetables, leaving room to expand.',
      'Arrange the stuffed vegetables snugly in a baking dish, replace their tops, and drizzle generously with olive oil.',
      'Add potato wedges around the vegetables and pour a little water into the base of the dish.',
      'Bake until the vegetables are soft and caramelized and the rice is fully cooked.',
      'Let rest for ten minutes and serve drizzled with the pan juices.'
    ],
    'greek', true, 260, 5, 45, 8, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/gemista-stuffed-tomatoes-and-peppers.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'large tomatoes', '6'),
    (recipe_id, 'used', 'bell peppers', '3'),
    (recipe_id, 'used', 'white rice', '200g'),
    (recipe_id, 'used', 'onion', '1, finely chopped'),
    (recipe_id, 'used', 'fresh parsley', '3 tbsp, chopped'),
    (recipe_id, 'used', 'fresh mint', '2 tbsp, chopped'),
    (recipe_id, 'used', 'olive oil', '120ml'),
    (recipe_id, 'used', 'potatoes', '2, cut into wedges'),
    (recipe_id, 'used', 'sugar', '1 pinch');
END $$;

-- ─── Recipe 45: Briam Roasted Vegetable Bake ───────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000045';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Briam Roasted Vegetable Bake',
    'A rustic medley of zucchini, potatoes, and eggplant slow-roasted in olive oil and tomato until meltingly tender.',
    75, 4,
    ARRAY[
      'Slice the potatoes, zucchini, and eggplant into thick rounds and toss them in a large bowl with sliced onion.',
      'Whisk together the crushed tomatoes, olive oil, garlic, and oregano to make a loose sauce.',
      'Spread the vegetables in a large baking dish and pour the tomato mixture over the top, tossing to coat everything evenly.',
      'Nestle the cherry tomatoes among the vegetables and season generously with salt and pepper.',
      'Cover the dish with foil and roast until the vegetables begin to soften.',
      'Remove the foil and continue roasting until the vegetables are tender and the top is lightly caramelized.',
      'Scatter fresh parsley over the top before serving warm or at room temperature.'
    ],
    'greek', true, 220, 4, 28, 11, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/briam-roasted-vegetable-bake.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'potatoes', '2, sliced'),
    (recipe_id, 'used', 'zucchini', '2, sliced'),
    (recipe_id, 'used', 'eggplant', '1, sliced'),
    (recipe_id, 'used', 'onion', '1, sliced'),
    (recipe_id, 'used', 'cherry tomatoes', '200g'),
    (recipe_id, 'used', 'crushed tomatoes', '200g'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'olive oil', '100ml'),
    (recipe_id, 'used', 'dried oregano', '1 tbsp');
END $$;

-- ─── Recipe 46: Horiatiki Village Salad with Feta ──────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000046';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Horiatiki Village Salad with Feta',
    'Crisp tomatoes, cucumber, onion, and olives crowned with a thick slab of feta and a generous pour of olive oil.',
    15, 4,
    ARRAY[
      'Cut the tomatoes into wedges and the cucumber into thick half-moons, and place them in a wide bowl.',
      'Thinly slice the red onion and green pepper and add them to the bowl along with the kalamata olives.',
      'Toss the vegetables gently with a pinch of salt and dried oregano.',
      'Arrange the salad on a platter and place a whole slab of feta on top.',
      'Drizzle generously with olive oil and a splash of red wine vinegar.',
      'Finish with an extra sprinkle of oregano and serve with crusty bread on the side.'
    ],
    'greek', true, 280, 7, 12, 23, 'vegetarian', ARRAY['Gluten-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/horiatiki-village-salad-with-feta.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'tomatoes', '4, cut into wedges'),
    (recipe_id, 'used', 'cucumber', '1, sliced'),
    (recipe_id, 'used', 'red onion', '1/2, thinly sliced'),
    (recipe_id, 'used', 'green bell pepper', '1, sliced'),
    (recipe_id, 'used', 'kalamata olives', '100g'),
    (recipe_id, 'used', 'feta cheese', '200g, in a slab'),
    (recipe_id, 'used', 'olive oil', '60ml'),
    (recipe_id, 'used', 'red wine vinegar', '1 tbsp'),
    (recipe_id, 'used', 'dried oregano', '1 tsp');
END $$;

-- ─── Recipe 47: Fasolada White Bean Soup ───────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000047';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Fasolada White Bean Soup',
    'Greece''s hearty national soup of white beans, carrots, and celery simmered in a rich tomato broth.',
    100, 6,
    ARRAY[
      'Soak the dried beans overnight in plenty of water, then drain and rinse.',
      'Boil the beans in fresh water for about ten minutes, skimming off any foam, then drain again.',
      'Heat olive oil in a large pot and sauté the onion, carrot, and celery until softened.',
      'Return the beans to the pot along with the crushed tomatoes, tomato paste, and enough water to cover generously.',
      'Bring to a boil, then reduce to a gentle simmer and cook until the beans are tender and the broth has thickened slightly.',
      'Season with salt, pepper, and a bay leaf partway through cooking.',
      'Stir in chopped parsley just before serving and finish each bowl with a drizzle of olive oil.'
    ],
    'greek', true, 260, 12, 40, 6, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/fasolada-white-bean-soup.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'dried white beans', '400g'),
    (recipe_id, 'used', 'onion', '1, chopped'),
    (recipe_id, 'used', 'carrots', '2, sliced'),
    (recipe_id, 'used', 'celery stalks', '2, sliced'),
    (recipe_id, 'used', 'crushed tomatoes', '400g'),
    (recipe_id, 'used', 'tomato paste', '2 tbsp'),
    (recipe_id, 'used', 'olive oil', '80ml'),
    (recipe_id, 'used', 'bay leaf', '1'),
    (recipe_id, 'used', 'fresh parsley', '3 tbsp, chopped');
END $$;

-- ─── Recipe 48: Keftedes Herbed Meatballs ──────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000048';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Keftedes Herbed Meatballs',
    'Juicy pan-fried meatballs perfumed with mint, oregano, and grated onion, best eaten piping hot with a squeeze of lemon.',
    45, 4,
    ARRAY[
      'Soak the stale bread in water briefly, then squeeze out the excess liquid and crumble it into a large bowl.',
      'Add the ground beef, grated onion, garlic, egg, mint, and oregano to the bowl and mix gently with your hands.',
      'Season the mixture with salt and pepper and let it rest in the refrigerator for at least twenty minutes.',
      'Shape the mixture into small oval meatballs and lightly dust them in flour.',
      'Heat a generous layer of olive oil in a skillet over medium heat.',
      'Fry the meatballs in batches, turning occasionally, until deeply browned and cooked through.',
      'Drain on paper towels and serve hot with lemon wedges.'
    ],
    'greek', true, 340, 22, 14, 21, 'any', ARRAY['Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/keftedes-herbed-meatballs.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'ground beef', '500g'),
    (recipe_id, 'used', 'stale bread', '2 slices'),
    (recipe_id, 'used', 'onion', '1, grated'),
    (recipe_id, 'used', 'garlic', '2 cloves, minced'),
    (recipe_id, 'used', 'egg', '1'),
    (recipe_id, 'used', 'fresh mint', '2 tbsp, chopped'),
    (recipe_id, 'used', 'dried oregano', '1 tsp'),
    (recipe_id, 'used', 'flour', '3 tbsp, for dusting'),
    (recipe_id, 'used', 'olive oil', '100ml, for frying');
END $$;

-- ─── Recipe 49: Dakos Cretan Barley Salad ──────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000049';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Dakos Cretan Barley Salad',
    'A refreshing Cretan classic of soaked barley rusks piled high with juicy tomato, crumbled feta, and olives.',
    15, 4,
    ARRAY[
      'Grate the ripe tomatoes on the large holes of a box grater directly into a bowl, discarding the skins.',
      'Season the grated tomato with salt, olive oil, and a little red wine vinegar.',
      'Lightly moisten each barley rusk with a splash of water so it softens slightly without going soggy.',
      'Spoon the tomato mixture generously over each rusk.',
      'Crumble the feta cheese over the top and scatter with kalamata olives.',
      'Finish with a drizzle of olive oil and a sprinkle of dried oregano before serving immediately.'
    ],
    'greek', true, 260, 8, 26, 15, 'vegetarian', ARRAY['Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/dakos-cretan-barley-salad.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'barley rusks', '4'),
    (recipe_id, 'used', 'ripe tomatoes', '4, grated'),
    (recipe_id, 'used', 'feta cheese', '150g, crumbled'),
    (recipe_id, 'used', 'kalamata olives', '60g'),
    (recipe_id, 'used', 'olive oil', '60ml'),
    (recipe_id, 'used', 'dried oregano', '1 tsp'),
    (recipe_id, 'used', 'red wine vinegar', '1 tsp');
END $$;

-- ─── Recipe 50: Gigantes Plaki Baked Giant Beans ───────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000050';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Gigantes Plaki Baked Giant Beans',
    'Enormous butter beans baked low and slow in a sweet, herby tomato sauce until creamy and caramelized at the edges.',
    100, 6,
    ARRAY[
      'Soak the dried giant beans overnight, then drain and simmer in fresh water until just tender, about forty minutes.',
      'Drain the beans and set aside, reserving a little of the cooking liquid.',
      'Sauté the onion, carrot, and garlic in olive oil until softened and fragrant.',
      'Stir in the crushed tomatoes, tomato paste, honey, and a splash of the reserved bean liquid, and simmer briefly.',
      'Fold the beans into the sauce and transfer everything to a baking dish.',
      'Scatter chopped parsley and dill over the top and drizzle with more olive oil.',
      'Bake uncovered until the sauce has thickened and the top beans are lightly caramelized.',
      'Rest for ten minutes before serving warm or at room temperature.'
    ],
    'greek', true, 280, 12, 38, 9, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/gigantes-plaki-baked-giant-beans.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'dried giant beans (gigantes)', '400g'),
    (recipe_id, 'used', 'onion', '1, chopped'),
    (recipe_id, 'used', 'carrot', '1, diced'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'crushed tomatoes', '400g'),
    (recipe_id, 'used', 'tomato paste', '1 tbsp'),
    (recipe_id, 'used', 'honey', '1 tsp'),
    (recipe_id, 'used', 'fresh parsley', '2 tbsp, chopped'),
    (recipe_id, 'used', 'fresh dill', '2 tbsp, chopped'),
    (recipe_id, 'used', 'olive oil', '100ml');
END $$;

-- ─── Recipe 51: Saganaki Pan-Seared Cheese ─────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000051';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Saganaki Pan-Seared Cheese',
    'A sizzling appetizer of thick-cut cheese pan-fried to a crisp golden crust and finished with a bright squeeze of lemon.',
    15, 4,
    ARRAY[
      'Cut the cheese into thick slabs and pat them dry with paper towels.',
      'Dip each slab briefly in water, then dredge thoroughly in flour, shaking off the excess.',
      'Heat olive oil in a heavy skillet over medium-high heat until shimmering.',
      'Lay the cheese slabs in the hot oil and fry without moving until a deep golden crust forms on the bottom.',
      'Carefully flip and fry the other side until equally golden.',
      'Transfer to a plate and squeeze fresh lemon juice over the top immediately.',
      'Finish with a light sprinkle of dried oregano and serve at once while the crust is still crackling.'
    ],
    'greek', true, 310, 16, 10, 22, 'vegetarian', ARRAY['Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/saganaki-pan-seared-cheese.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'kefalotyri or graviera cheese', '300g'),
    (recipe_id, 'used', 'flour', '60g'),
    (recipe_id, 'used', 'olive oil', '60ml'),
    (recipe_id, 'used', 'lemon', '1'),
    (recipe_id, 'used', 'water', '2 tbsp, for dredging'),
    (recipe_id, 'used', 'dried oregano', '1/2 tsp');
END $$;

-- ─── Recipe 52: Lamb Chops with Oregano and Lemon ──────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000052';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Lamb Chops with Oregano and Lemon',
    'Quick-marinated lamb chops grilled hot and fast until charred outside and blushing pink within.',
    35, 4,
    ARRAY[
      'Whisk together olive oil, lemon juice, garlic, and oregano in a shallow dish to make the marinade.',
      'Add the lamb chops and turn to coat, then let marinate at room temperature for at least twenty minutes.',
      'Heat a grill pan or outdoor grill until very hot.',
      'Remove the chops from the marinade, season generously with salt and pepper, and shake off any excess liquid.',
      'Grill the chops for a few minutes per side until well charred outside and still pink in the center.',
      'Rest the chops for five minutes under loose foil.',
      'Serve with extra lemon wedges and a scattering of fresh oregano.'
    ],
    'greek', true, 420, 30, 3, 32, 'any', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/lamb-chops-with-oregano-and-lemon.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'lamb chops', '8'),
    (recipe_id, 'used', 'olive oil', '60ml'),
    (recipe_id, 'used', 'lemon juice', '3 tbsp'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'dried oregano', '2 tsp'),
    (recipe_id, 'used', 'lemon', '1, for serving');
END $$;

-- ─── Recipe 53: Psari Plaki Baked Fish with Tomatoes ───────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000053';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Psari Plaki Baked Fish with Tomatoes',
    'Whole fish fillets baked over a bed of tomatoes, onions, and herbs until flaky and infused with Mediterranean flavor.',
    50, 4,
    ARRAY[
      'Preheat the oven and generously oil a baking dish.',
      'Scatter the sliced onion and garlic over the base of the dish and top with sliced tomatoes.',
      'Drizzle with olive oil and season with salt, pepper, and dried oregano.',
      'Bake the vegetables alone for about fifteen minutes to soften slightly.',
      'Nestle the fish fillets into the vegetables, tucking lemon slices around them.',
      'Pour a splash of white wine over everything and drizzle with more olive oil.',
      'Bake until the fish flakes easily with a fork and the vegetables are soft.',
      'Scatter with fresh parsley before serving straight from the dish.'
    ],
    'greek', true, 300, 28, 10, 16, 'pescatarian', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    NULL);
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'white fish fillets', '600g (such as sea bream or cod)'),
    (recipe_id, 'used', 'tomatoes', '3, sliced'),
    (recipe_id, 'used', 'onion', '1, sliced'),
    (recipe_id, 'used', 'garlic', '3 cloves, sliced'),
    (recipe_id, 'used', 'lemon', '1, sliced'),
    (recipe_id, 'used', 'white wine', '80ml'),
    (recipe_id, 'used', 'olive oil', '80ml'),
    (recipe_id, 'used', 'dried oregano', '1 tsp'),
    (recipe_id, 'used', 'fresh parsley', '2 tbsp, chopped');
END $$;

-- ─── Recipe 54: Revithada Chickpea Stew ────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000054';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Revithada Chickpea Stew',
    'A Sifnos-style Sunday classic of chickpeas slow-baked in an earthenware pot with olive oil, onion, and bay leaf until creamy.',
    130, 4,
    ARRAY[
      'Soak the dried chickpeas overnight with a pinch of baking soda, then drain and rinse well.',
      'Combine the chickpeas, sliced onion, bay leaves, and olive oil in a heavy ovenproof pot and cover with water.',
      'Bring to a boil on the stovetop, skimming off any foam that rises to the surface.',
      'Season with salt and transfer the pot, covered, into a low oven.',
      'Bake slowly for several hours, checking occasionally and topping up with hot water if the level drops too low.',
      'Once the chickpeas are completely tender and the liquid has reduced to a creamy consistency, remove the bay leaves.',
      'Finish with a generous drizzle of fresh olive oil and a squeeze of lemon before serving.'
    ],
    'greek', true, 320, 14, 45, 10, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/revithada-chickpea-stew.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'dried chickpeas', '400g'),
    (recipe_id, 'used', 'onion', '1, sliced'),
    (recipe_id, 'used', 'bay leaves', '2'),
    (recipe_id, 'used', 'olive oil', '120ml'),
    (recipe_id, 'used', 'baking soda', '1/2 tsp'),
    (recipe_id, 'used', 'lemon', '1'),
    (recipe_id, 'used', 'black pepper', 'to taste');
END $$;

-- ─── Recipe 55: Loukaniko with Peppers and Onions ──────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000055';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Loukaniko with Peppers and Onions',
    'Coarse, fennel-spiced Greek sausages seared until crisp and tumbled with sweet peppers and onions.',
    35, 4,
    ARRAY[
      'Prick the sausages a few times with a fork and heat olive oil in a large skillet over medium heat.',
      'Sear the sausages on all sides until browned, then remove and set aside.',
      'Add the sliced peppers and onions to the same skillet and cook in the rendered fat until softened and lightly caramelized.',
      'Stir in the garlic and dried oregano and cook briefly until fragrant.',
      'Return the sausages to the skillet, nestling them among the peppers and onions.',
      'Add a splash of orange juice and simmer until the sausages are cooked through.',
      'Finish with a squeeze of lemon and scatter with fresh parsley before serving.'
    ],
    'greek', true, 360, 18, 10, 27, 'any', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/loukaniko-with-peppers-and-onions.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'loukaniko sausages', '500g'),
    (recipe_id, 'used', 'bell peppers', '3, sliced'),
    (recipe_id, 'used', 'onion', '2, sliced'),
    (recipe_id, 'used', 'garlic', '2 cloves, minced'),
    (recipe_id, 'used', 'dried oregano', '1 tsp'),
    (recipe_id, 'used', 'orange juice', '60ml'),
    (recipe_id, 'used', 'olive oil', '2 tbsp'),
    (recipe_id, 'used', 'lemon', '1');
END $$;

-- ─── Recipe 56: Melitzanosalata Smoky Eggplant Dip ─────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000056';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Melitzanosalata Smoky Eggplant Dip',
    'Charred eggplant blended with garlic, olive oil, and lemon into a smoky, silky dip perfect for scooping with warm bread.',
    45, 6,
    ARRAY[
      'Char the whole eggplants directly over a flame or under a hot broiler, turning occasionally, until the skin is blackened and blistered all over.',
      'Transfer the eggplants to a covered bowl and let them steam for ten minutes to loosen the skin.',
      'Peel away the charred skin and drain the flesh in a colander to remove excess liquid.',
      'Finely chop the eggplant flesh and transfer it to a bowl.',
      'Stir in the minced garlic, olive oil, lemon juice, and finely chopped onion.',
      'Season with salt and pepper and mix until the dip comes together.',
      'Chill briefly, then drizzle with a little extra olive oil and scatter with parsley before serving.'
    ],
    'greek', true, 110, 2, 8, 8, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/melitzanosalata-smoky-eggplant-dip.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'eggplants', '3 large'),
    (recipe_id, 'used', 'garlic', '2 cloves, minced'),
    (recipe_id, 'used', 'olive oil', '80ml'),
    (recipe_id, 'used', 'lemon juice', '2 tbsp'),
    (recipe_id, 'used', 'red onion', '2 tbsp, finely chopped'),
    (recipe_id, 'used', 'fresh parsley', '2 tbsp, chopped');
END $$;

-- ─── Recipe 57: Youvetsi Baked Orzo with Braised Lamb ──────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000057';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Youvetsi Baked Orzo with Braised Lamb',
    'Tender braised lamb and orzo baked together in a rich cinnamon-spiced tomato sauce until the pasta turns deeply savory.',
    120, 6,
    ARRAY[
      'Season the lamb pieces with salt and pepper and brown them in olive oil in a heavy pot, working in batches.',
      'Remove the lamb and sauté the onion and garlic in the same pot until softened.',
      'Stir in the tomato paste, crushed tomatoes, and cinnamon stick, then return the lamb to the pot.',
      'Cover and simmer gently over low heat until the lamb is fork-tender, adding water as needed.',
      'Remove the lamb, shred or cube the meat, and stir it back into the sauce along with enough broth to cover the orzo.',
      'Transfer everything to a baking dish, stir in the raw orzo, and spread it into an even layer.',
      'Cover and bake until the orzo has absorbed the liquid and is tender, stirring once halfway through.',
      'Sprinkle with grated cheese and let rest for a few minutes before serving.'
    ],
    'greek', true, 480, 26, 40, 22, 'any', ARRAY['Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/youvetsi-baked-orzo-with-braised-lamb.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'lamb shoulder', '700g, cut into chunks'),
    (recipe_id, 'used', 'orzo pasta', '300g'),
    (recipe_id, 'used', 'onion', '1, chopped'),
    (recipe_id, 'used', 'garlic', '3 cloves, minced'),
    (recipe_id, 'used', 'crushed tomatoes', '400g'),
    (recipe_id, 'used', 'tomato paste', '2 tbsp'),
    (recipe_id, 'used', 'cinnamon stick', '1'),
    (recipe_id, 'used', 'lamb or beef broth', '500ml'),
    (recipe_id, 'used', 'grated hard cheese', '60g');
END $$;

-- ─── Recipe 58: Kolokithokeftedes Zucchini Fritters ────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000058';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Kolokithokeftedes Zucchini Fritters',
    'Crisp-edged fritters of grated zucchini, feta, and fresh herbs, fried until golden and served with a squeeze of lemon.',
    40, 4,
    ARRAY[
      'Grate the zucchini coarsely, toss with salt, and let sit in a colander for fifteen minutes to draw out excess moisture.',
      'Squeeze the zucchini firmly in a clean kitchen towel to remove as much liquid as possible.',
      'Combine the zucchini with crumbled feta, grated onion, chopped dill and mint, and beaten egg in a large bowl.',
      'Stir in enough flour to bind the mixture into a thick, scoopable batter.',
      'Heat a shallow layer of olive oil in a skillet over medium heat.',
      'Drop spoonfuls of the batter into the hot oil, flattening slightly, and fry until golden on both sides.',
      'Drain on paper towels and serve warm with lemon wedges.'
    ],
    'greek', true, 240, 8, 20, 14, 'vegetarian', ARRAY['Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/kolokithokeftedes-zucchini-fritters.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'zucchini', '500g, grated'),
    (recipe_id, 'used', 'feta cheese', '100g, crumbled'),
    (recipe_id, 'used', 'onion', '1/2, grated'),
    (recipe_id, 'used', 'fresh dill', '2 tbsp, chopped'),
    (recipe_id, 'used', 'fresh mint', '1 tbsp, chopped'),
    (recipe_id, 'used', 'egg', '1'),
    (recipe_id, 'used', 'flour', '80g'),
    (recipe_id, 'used', 'olive oil', 'for frying');
END $$;

-- ─── Recipe 59: Galaktoboureko Custard Phyllo Pie ──────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000059';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Galaktoboureko Custard Phyllo Pie',
    'A dreamy baked custard pie wrapped in crisp golden phyllo and soaked in a fragrant citrus syrup.',
    90, 8,
    ARRAY[
      'Heat the milk in a saucepan with the vanilla and a strip of lemon zest until just simmering.',
      'Whisk the eggs, sugar, and semolina together in a bowl, then slowly pour in the hot milk while whisking constantly.',
      'Return the mixture to the saucepan and cook over low heat, stirring constantly, until it thickens into a custard.',
      'Layer half the phyllo sheets in a buttered baking dish, brushing each sheet with melted butter as you go.',
      'Pour the warm custard over the phyllo base and spread it evenly.',
      'Layer the remaining phyllo sheets on top, brushing each with butter, and tuck the edges into the dish.',
      'Score the top layer into portions and bake until deeply golden.',
      'While still hot, pour the cooled lemon syrup evenly over the pie and let it soak in fully before slicing.'
    ],
    'greek', true, 310, 6, 40, 14, 'vegetarian', ARRAY['Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/galaktoboureko-custard-phyllo-pie.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'phyllo dough', '12 sheets'),
    (recipe_id, 'used', 'whole milk', '1 liter'),
    (recipe_id, 'used', 'semolina', '120g'),
    (recipe_id, 'used', 'eggs', '4'),
    (recipe_id, 'used', 'sugar', '200g'),
    (recipe_id, 'used', 'butter', '150g, melted'),
    (recipe_id, 'used', 'vanilla extract', '1 tsp'),
    (recipe_id, 'used', 'lemon', '1, for zest and syrup'),
    (recipe_id, 'used', 'water', '200ml, for syrup');
END $$;

-- ─── Recipe 60: Soutzoukakia Baked Meatballs in Tomato Sauce ───────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000060';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Soutzoukakia Baked Meatballs in Tomato Sauce',
    'Cumin-spiced oblong meatballs from Smyrna, simmered in a rich tomato sauce until deeply aromatic.',
    60, 4,
    ARRAY[
      'Soak the stale bread in water, then squeeze dry and combine with the ground beef, grated onion, garlic, and egg in a bowl.',
      'Season the meat mixture with ground cumin, salt, and pepper, and mix gently until just combined.',
      'Shape the mixture into small oblong logs and dust lightly with flour.',
      'Heat olive oil in a skillet and brown the meatballs on all sides, then set aside.',
      'In the same pan, simmer the crushed tomatoes, tomato paste, and a pinch of sugar until slightly thickened.',
      'Return the meatballs to the sauce, cover, and simmer gently until cooked through and infused with the tomato flavor.',
      'Sprinkle with chopped parsley and serve hot, ideally with rice or bread.'
    ],
    'greek', true, 380, 24, 16, 24, 'any', ARRAY['Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/soutzoukakia-baked-meatballs-in-tomato-sauce.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'ground beef', '500g'),
    (recipe_id, 'used', 'stale bread', '2 slices'),
    (recipe_id, 'used', 'onion', '1, grated'),
    (recipe_id, 'used', 'garlic', '2 cloves, minced'),
    (recipe_id, 'used', 'ground cumin', '1 tsp'),
    (recipe_id, 'used', 'crushed tomatoes', '400g'),
    (recipe_id, 'used', 'tomato paste', '1 tbsp'),
    (recipe_id, 'used', 'flour', '2 tbsp'),
    (recipe_id, 'used', 'olive oil', '3 tbsp');
END $$;
