-- ============================================================
-- UseUp — Seed 20 Korean Recipes (IDs 61–80)
-- ============================================================

-- ─── Recipe 61: Dolsot Bibimbap ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000061';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Dolsot Bibimbap',
    'A sizzling stone pot of rice topped with seasoned vegetables, marinated beef, and a raw egg that cooks into a crisp golden crust as you mix.',
    40, 2,
    ARRAY[
      'Marinate the thinly sliced beef in soy sauce, half the sesame oil, and minced garlic for at least 15 minutes.',
      'Blanch the spinach and bean sprouts separately in boiling water, then squeeze dry and season each lightly with salt and sesame oil.',
      'Sauté the julienned carrot and sliced shiitake mushrooms separately in a hot pan until just tender, seasoning each with a pinch of salt.',
      'Sear the marinated beef in a hot pan until browned and cooked through, about 3 minutes.',
      'Heat a stone pot over high heat, rub the inside lightly with sesame oil, then add a layer of warm rice, pressing it down so it crisps against the hot surface.',
      'Arrange the beef and vegetables in separate mounds on top of the rice, crack a raw egg into the center, and let the pot sizzle for 1-2 minutes to crisp the rice at the bottom.',
      'Serve immediately with a generous spoonful of gochujang on the side, mixing everything together at the table just before eating.'
    ],
    'korean', true, 650, 28, 80, 22, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/dolsot-bibimbap.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'cooked short-grain rice', '2 cups'),
    (recipe_id, 'used', 'beef sirloin, thinly sliced', '200g'),
    (recipe_id, 'used', 'soy sauce', '2 tbsp'),
    (recipe_id, 'used', 'sesame oil', '1 tbsp'),
    (recipe_id, 'used', 'garlic, minced', '2 cloves'),
    (recipe_id, 'used', 'spinach, blanched', '1 cup'),
    (recipe_id, 'used', 'carrot, julienned', '1/2 cup'),
    (recipe_id, 'used', 'shiitake mushrooms, sliced', '1/2 cup'),
    (recipe_id, 'used', 'eggs', '2'),
    (recipe_id, 'used', 'gochujang', '3 tbsp');
END $$;

-- ─── Recipe 62: Japchae ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000062';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Japchae',
    'Chewy sweet potato glass noodles tossed with silky sesame oil and a rainbow of tender vegetables, a beloved centerpiece of any Korean spread.',
    35, 4,
    ARRAY[
      'Soak the sweet potato starch noodles in warm water for 30 minutes until pliable, then boil for 5-6 minutes and drain.',
      'Toss the drained noodles immediately with 2 tablespoons of soy sauce, the sugar, and 1 tablespoon of sesame oil, then set aside.',
      'Blanch the spinach briefly, squeeze out excess water, and season with a pinch of salt and a few drops of sesame oil.',
      'Stir-fry the julienned carrot, sliced onion, shiitake mushrooms, and minced garlic separately in a hot pan with a little oil until each is just tender.',
      'Combine the noodles, spinach, and stir-fried vegetables in a large bowl, then add the remaining soy sauce and sesame oil and toss thoroughly.',
      'Taste and adjust the seasoning with extra soy sauce or sugar as needed.',
      'Garnish with toasted sesame seeds and serve warm or at room temperature.'
    ],
    'korean', true, 320, 6, 55, 9, 'vegan', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/japchae.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'sweet potato starch noodles', '200g'),
    (recipe_id, 'used', 'soy sauce', '4 tbsp'),
    (recipe_id, 'used', 'sugar', '2 tbsp'),
    (recipe_id, 'used', 'sesame oil', '3 tbsp'),
    (recipe_id, 'used', 'spinach', '2 cups'),
    (recipe_id, 'used', 'carrot, julienned', '1'),
    (recipe_id, 'used', 'onion, sliced', '1'),
    (recipe_id, 'used', 'shiitake mushrooms, sliced', '1 cup'),
    (recipe_id, 'used', 'garlic, minced', '2 cloves'),
    (recipe_id, 'used', 'toasted sesame seeds', '1 tbsp');
END $$;

-- ─── Recipe 63: Spicy Tteokbokki ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000063';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Spicy Tteokbokki',
    'Chewy rice cakes and fish cake simmered in a glossy, fiery-sweet gochujang sauce, the ultimate Korean street food fix.',
    25, 3,
    ARRAY[
      'If the rice cakes are firm or refrigerated, soak them in warm water for 10 minutes to soften.',
      'Bring the anchovy-kelp stock to a simmer in a wide pan and whisk in the gochujang, gochugaru, soy sauce, sugar, and minced garlic.',
      'Add the rice cakes and sliced fish cake to the simmering sauce, stirring gently to coat.',
      'Simmer for 10-12 minutes, stirring occasionally, until the rice cakes are soft and the sauce has thickened and clings to them.',
      'Adjust the heat level and sweetness to taste, adding a splash more stock if the sauce reduces too much.',
      'Stir in half of the chopped scallions during the last minute of cooking.',
      'Transfer to a serving dish, top with the boiled egg and remaining scallions, and serve hot.'
    ],
    'korean', true, 380, 10, 70, 6, 'pescatarian', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/spicy-tteokbokki.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'korean rice cakes (tteok)', '400g'),
    (recipe_id, 'used', 'fish cake (eomuk), sliced', '150g'),
    (recipe_id, 'used', 'gochujang', '3 tbsp'),
    (recipe_id, 'used', 'gochugaru', '1 tbsp'),
    (recipe_id, 'used', 'soy sauce', '1 tbsp'),
    (recipe_id, 'used', 'sugar', '2 tbsp'),
    (recipe_id, 'used', 'garlic, minced', '2 cloves'),
    (recipe_id, 'used', 'anchovy-kelp stock', '2 cups'),
    (recipe_id, 'used', 'scallions, chopped', '2'),
    (recipe_id, 'used', 'boiled egg', '1');
END $$;

-- ─── Recipe 64: Sundubu Jjigae ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000064';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Sundubu Jjigae',
    'A bubbling, fiery stone pot of silky soft tofu, shrimp, and clams in a deep red broth, finished with a raw egg cracked in tableside.',
    30, 2,
    ARRAY[
      'Heat sesame oil in a stone pot or heavy saucepan and sauté the minced garlic and gochugaru briefly until fragrant.',
      'Add the diced onion and zucchini and stir-fry for 2 minutes.',
      'Pour in the anchovy stock and bring to a simmer.',
      'Add the clams and shrimp and cook for 2-3 minutes until the clams begin to open.',
      'Spoon the soft tofu directly into the pot in large curds, without draining it first, and simmer for 3-4 minutes.',
      'Crack the egg into the center of the bubbling stew just before serving and let it cook gently in the residual heat.',
      'Sprinkle with chopped scallions and serve immediately while still boiling.'
    ],
    'korean', true, 340, 24, 14, 20, 'pescatarian', ARRAY['Dairy-Free', 'Nut-Free'],
    '00000000-0000-0000-0000-000000555570/sundubu-jjigae.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'soft tofu (sundubu)', '1 tube, about 400g'),
    (recipe_id, 'used', 'shrimp, peeled', '100g'),
    (recipe_id, 'used', 'clams', '100g'),
    (recipe_id, 'used', 'gochugaru', '2 tbsp'),
    (recipe_id, 'used', 'sesame oil', '1 tbsp'),
    (recipe_id, 'used', 'garlic, minced', '2 cloves'),
    (recipe_id, 'used', 'onion, diced', '1/2'),
    (recipe_id, 'used', 'zucchini, diced', '1/2'),
    (recipe_id, 'used', 'anchovy stock', '2 cups'),
    (recipe_id, 'used', 'egg', '1');
END $$;

-- ─── Recipe 65: Vegetable Gimbap ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000065';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Vegetable Gimbap',
    'Neat spirals of seasoned rice, crisp vegetables, and golden egg rolled tight in toasted seaweed, sliced into perfect bite-sized pinwheels.',
    45, 4,
    ARRAY[
      'Season the warm cooked rice with sesame oil and a pinch of salt, then let it cool slightly.',
      'Blanch the spinach, squeeze dry, and season lightly with salt and sesame oil.',
      'Sauté the julienned carrot in a hot pan with a little oil until just softened, and season with a pinch of salt.',
      'Beat the eggs, pour into a lightly oiled pan, and cook into a thin sheet, then slice into strips.',
      'Lay a sheet of seaweed shiny-side down on a bamboo mat and spread an even layer of rice across it, leaving a small border at the top.',
      'Arrange the spinach, carrot, egg strips, pickled radish, and cucumber in a line across the center of the rice.',
      'Roll the mat away from you, pressing firmly to form a tight cylinder, then seal the edge with a few grains of rice.',
      'Slice the roll into bite-sized pieces with a sharp knife and serve.'
    ],
    'korean', true, 310, 8, 55, 7, 'vegetarian', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/vegetable-gimbap.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'cooked short-grain rice', '3 cups'),
    (recipe_id, 'used', 'sesame oil', '2 tbsp'),
    (recipe_id, 'used', 'roasted seaweed sheets (gim)', '4'),
    (recipe_id, 'used', 'spinach, blanched', '1 cup'),
    (recipe_id, 'used', 'carrot, julienned', '1'),
    (recipe_id, 'used', 'pickled radish (danmuji)', '4 strips'),
    (recipe_id, 'used', 'eggs', '2'),
    (recipe_id, 'used', 'cucumber, julienned', '1'),
    (recipe_id, 'used', 'salt', '1 tsp');
END $$;

-- ─── Recipe 66: Kimchi Fried Rice ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000066';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Kimchi Fried Rice',
    'Tangy, well-fermented kimchi and smoky bacon fried together with day-old rice and topped with a glistening fried egg.',
    20, 2,
    ARRAY[
      'Cook the diced bacon in a large pan over medium heat until browned and crisp, then remove excess fat if needed.',
      'Add the chopped kimchi and stir-fry for 2-3 minutes until slightly caramelized.',
      'Stir in the kimchi juice and gochujang, mixing well to coat the kimchi.',
      'Add the cooked rice, breaking up any clumps, and toss everything together until evenly combined and heated through.',
      'Drizzle with sesame oil and stir-fry for another minute, then push the rice to one side of the pan.',
      'Fry the eggs sunny-side up in the cleared space, or in a separate pan if preferred.',
      'Plate the fried rice, top each portion with a fried egg, and garnish with scallions and seaweed strips.'
    ],
    'korean', true, 520, 18, 60, 22, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/kimchi-fried-rice.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'day-old cooked rice', '3 cups'),
    (recipe_id, 'used', 'ripe kimchi, chopped', '1 cup'),
    (recipe_id, 'used', 'kimchi juice', '2 tbsp'),
    (recipe_id, 'used', 'bacon, diced', '100g'),
    (recipe_id, 'used', 'gochujang', '1 tbsp'),
    (recipe_id, 'used', 'sesame oil', '2 tbsp'),
    (recipe_id, 'used', 'egg', '2'),
    (recipe_id, 'used', 'scallions, chopped', '2'),
    (recipe_id, 'used', 'roasted seaweed strips', 'for garnish');
END $$;

-- ─── Recipe 67: Doenjang Jjigae ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000067';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Doenjang Jjigae',
    'A rustic, earthy stew of fermented soybean paste simmered with tofu, zucchini, and potato into a deeply savory everyday comfort dish.',
    30, 3,
    ARRAY[
      'Bring the vegetable stock to a boil in a saucepan.',
      'Dissolve the doenjang into the hot stock, whisking until smooth.',
      'Add the diced potato and onion and simmer for 5 minutes until the potato begins to soften.',
      'Add the zucchini, minced garlic, and gochugaru, and continue simmering for another 5 minutes.',
      'Gently add the cubed tofu and simmer for 3-4 more minutes without stirring too vigorously so the tofu stays intact.',
      'Taste and adjust the seasoning, adding a touch more doenjang if a deeper flavor is desired.',
      'Stir in the chopped scallions just before removing from the heat and serve bubbling hot with a bowl of steamed rice.'
    ],
    'korean', true, 180, 11, 20, 6, 'vegan', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/doenjang-jjigae.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'doenjang (fermented soybean paste)', '3 tbsp'),
    (recipe_id, 'used', 'firm tofu, cubed', '200g'),
    (recipe_id, 'used', 'zucchini, diced', '1'),
    (recipe_id, 'used', 'potato, diced', '1'),
    (recipe_id, 'used', 'onion, diced', '1/2'),
    (recipe_id, 'used', 'vegetable stock', '3 cups'),
    (recipe_id, 'used', 'garlic, minced', '2 cloves'),
    (recipe_id, 'used', 'gochugaru', '1 tsp'),
    (recipe_id, 'used', 'scallions, chopped', '1');
END $$;

-- ─── Recipe 68: Yangnyeom Dakgangjeong ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000068';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Yangnyeom Dakgangjeong',
    'Double-fried bites of chicken tossed in a sticky, glossy gochujang glaze with a perfect balance of sweet, spicy, and garlicky flavor.',
    50, 4,
    ARRAY[
      'Toss the cubed chicken thigh with a pinch of salt and pepper, then coat thoroughly in potato starch.',
      'Heat the oil to about 350°F (175°C) and fry the chicken in batches until golden and just cooked through, about 4-5 minutes per batch.',
      'Remove the chicken and let it rest briefly, then fry a second time for 1-2 minutes to make it extra crisp.',
      'In a separate pan, combine the gochujang, soy sauce, honey, rice syrup, minced garlic, and grated ginger, and simmer over low heat until thickened into a glossy glaze.',
      'Add the double-fried chicken to the pan and toss quickly to coat every piece evenly in the glaze.',
      'Remove from heat before the sugars scorch, working quickly to prevent the glaze from hardening.',
      'Transfer to a serving plate and sprinkle with toasted sesame seeds before serving hot.'
    ],
    'korean', true, 560, 32, 40, 28, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/yangnyeom-dakgangjeong.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'boneless chicken thigh, cubed', '700g'),
    (recipe_id, 'used', 'potato starch', '1 cup'),
    (recipe_id, 'used', 'vegetable oil, for frying', '3 cups'),
    (recipe_id, 'used', 'gochujang', '3 tbsp'),
    (recipe_id, 'used', 'soy sauce', '2 tbsp'),
    (recipe_id, 'used', 'honey', '2 tbsp'),
    (recipe_id, 'used', 'rice syrup or corn syrup', '2 tbsp'),
    (recipe_id, 'used', 'garlic, minced', '3 cloves'),
    (recipe_id, 'used', 'ginger, grated', '1 tsp'),
    (recipe_id, 'used', 'toasted sesame seeds', '1 tbsp');
END $$;

-- ─── Recipe 69: Budae Jjigae ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000069';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Budae Jjigae',
    'A hearty, communal hot pot of spam, sausage, kimchi, and ramen noodles simmered together in a spicy, savory broth.',
    35, 4,
    ARRAY[
      'Arrange the spam, sausage slices, chopped kimchi, tofu, and baked beans in sections around a wide, shallow pot.',
      'Whisk the gochujang and gochugaru into the stock, then pour the mixture into the pot to just cover the ingredients.',
      'Bring the pot to a boil over the table burner or stovetop, letting the flavors meld together.',
      'Once boiling, add the instant ramen noodles and their seasoning packet in moderation, adjusting spice to taste.',
      'Simmer for 4-5 minutes until the noodles are just cooked but still have some bite.',
      'Lay the cheese slice over the top so it melts into the broth.',
      'Serve straight from the pot while everything is still bubbling.'
    ],
    'korean', true, 610, 26, 45, 34, 'any', ARRAY['Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/budae-jjigae.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'canned luncheon meat (spam), sliced', '200g'),
    (recipe_id, 'used', 'hot dogs or sausages, sliced', '150g'),
    (recipe_id, 'used', 'kimchi, chopped', '1 cup'),
    (recipe_id, 'used', 'instant ramen noodles', '1 block'),
    (recipe_id, 'used', 'baked beans', '1/2 cup'),
    (recipe_id, 'used', 'gochujang', '2 tbsp'),
    (recipe_id, 'used', 'gochugaru', '1 tbsp'),
    (recipe_id, 'used', 'tofu, sliced', '100g'),
    (recipe_id, 'used', 'anchovy or chicken stock', '3 cups'),
    (recipe_id, 'used', 'processed cheese slice', '1');
END $$;

-- ─── Recipe 70: Jajangmyeon ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000070';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Jajangmyeon',
    'Thick wheat noodles drenched in a rich, glossy black bean sauce studded with tender pork and vegetables.',
    45, 4,
    ARRAY[
      'Fry the chunjang in vegetable oil over low heat for 2-3 minutes to mellow its raw, bitter edge, then set aside.',
      'Stir-fry the diced pork shoulder in a separate pot until browned.',
      'Add the diced onion, zucchini, and potato to the pork and stir-fry for a few minutes until the onion softens.',
      'Stir in the fried black bean paste, coating the meat and vegetables evenly, then add enough water to just cover everything.',
      'Simmer for 15-20 minutes until the potato is tender, stirring occasionally to prevent sticking.',
      'Thicken the sauce with the potato starch slurry, stirring until glossy and thick enough to coat a spoon.',
      'Boil the wheat noodles separately until just done, drain, and divide among bowls.',
      'Ladle the black bean sauce generously over the noodles and top with julienned cucumber before serving.'
    ],
    'korean', true, 590, 22, 85, 16, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/jajangmyeon.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'wheat noodles', '500g'),
    (recipe_id, 'used', 'pork shoulder, diced', '200g'),
    (recipe_id, 'used', 'chunjang (black bean paste)', '4 tbsp'),
    (recipe_id, 'used', 'onion, diced', '2'),
    (recipe_id, 'used', 'zucchini, diced', '1'),
    (recipe_id, 'used', 'potato, diced', '1'),
    (recipe_id, 'used', 'vegetable oil', '3 tbsp'),
    (recipe_id, 'used', 'potato starch slurry', '2 tbsp'),
    (recipe_id, 'used', 'cucumber, julienned', 'for garnish');
END $$;

-- ─── Recipe 71: LA Galbi ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000071';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'LA Galbi',
    'Flanken-cut beef short ribs marinated in a sweet soy and pear glaze, then grilled until caramelized and irresistibly smoky.',
    40, 4,
    ARRAY[
      'Soak the short ribs in cold water for 30 minutes, changing the water once, to draw out excess blood for a cleaner flavor.',
      'Whisk together the soy sauce, brown sugar, grated Asian pear, grated onion, minced garlic, sesame oil, and black pepper to make the marinade.',
      'Pat the ribs dry and submerge them in the marinade, massaging it into the meat.',
      'Cover and refrigerate for at least 4 hours, ideally overnight, turning occasionally.',
      'Remove the ribs from the fridge and let them come to room temperature for 20 minutes before cooking.',
      'Grill or pan-sear the ribs over high heat for 2-3 minutes per side until caramelized and cooked to medium.',
      'Rest the meat briefly, then garnish with chopped scallions and serve with lettuce leaves for wrapping.'
    ],
    'korean', true, 480, 30, 18, 30, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/la-galbi.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'LA-style beef short ribs (flanken cut)', '1kg'),
    (recipe_id, 'used', 'soy sauce', '1/2 cup'),
    (recipe_id, 'used', 'brown sugar', '3 tbsp'),
    (recipe_id, 'used', 'asian pear, grated', '1/2'),
    (recipe_id, 'used', 'onion, grated', '1/2'),
    (recipe_id, 'used', 'garlic, minced', '4 cloves'),
    (recipe_id, 'used', 'sesame oil', '2 tbsp'),
    (recipe_id, 'used', 'black pepper', '1/2 tsp'),
    (recipe_id, 'used', 'scallions, chopped', 'for garnish');
END $$;

-- ─── Recipe 72: Haemul Pajeon ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000072';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Haemul Pajeon',
    'A crisp-edged savory pancake packed with whole scallions, shrimp, squid, and mussels, perfect for sharing with a tangy dipping sauce.',
    30, 4,
    ARRAY[
      'Whisk the flour, ice water, and egg together into a smooth, thin batter.',
      'Lay the whole scallions flat in a hot, well-oiled pan to form a base layer.',
      'Scatter the shrimp, squid, and mussels evenly over the scallions.',
      'Ladle the batter over the top, spreading it to bind the scallions and seafood into one even layer.',
      'Cook over medium heat for 4-5 minutes until the bottom is golden and crisp.',
      'Carefully flip the pancake in one motion, pressing down gently, and cook the other side until equally crisp.',
      'Slide onto a cutting board, cut into wedges, and serve hot with a simple soy dipping sauce.'
    ],
    'korean', true, 340, 16, 32, 16, 'pescatarian', ARRAY['Dairy-Free', 'Nut-Free'],
    '00000000-0000-0000-0000-000000555570/haemul-pajeon.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'all-purpose flour', '1 cup'),
    (recipe_id, 'used', 'ice water', '1 cup'),
    (recipe_id, 'used', 'egg', '1'),
    (recipe_id, 'used', 'scallions, whole', '8-10'),
    (recipe_id, 'used', 'shrimp, chopped', '100g'),
    (recipe_id, 'used', 'squid, sliced', '100g'),
    (recipe_id, 'used', 'mussels, shelled', '50g'),
    (recipe_id, 'used', 'vegetable oil', 'for frying'),
    (recipe_id, 'used', 'soy sauce', 'for dipping');
END $$;

-- ─── Recipe 73: Mul Naengmyeon ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000073';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Mul Naengmyeon',
    'Ice-cold buckwheat noodles in a tangy, refreshing beef broth, topped with tender brisket, pear, and a jammy boiled egg.',
    40, 2,
    ARRAY[
      'Simmer the beef brisket in water with a few aromatics until tender, about 1 hour, then reserve the cooking liquid as stock.',
      'Strain the stock, skim off the fat, and season it with soy sauce, then chill it thoroughly in the refrigerator.',
      'Slice the cooked brisket thinly once cooled.',
      'Boil the naengmyeon noodles briefly according to the package, then rinse immediately under cold running water while rubbing to remove excess starch.',
      'Divide the chilled noodles among serving bowls and arrange the sliced brisket, cucumber, pear slices, and half a boiled egg on top of each.',
      'Pour the ice-cold seasoned stock over the noodles until they are just submerged.',
      'Finish with a splash of rice vinegar and serve with Korean mustard on the side for guests to adjust to taste.'
    ],
    'korean', true, 420, 22, 65, 8, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/mul-naengmyeon.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'buckwheat naengmyeon noodles', '400g'),
    (recipe_id, 'used', 'beef brisket', '300g'),
    (recipe_id, 'used', 'beef bone or brisket stock', '4 cups'),
    (recipe_id, 'used', 'soy sauce', '2 tbsp'),
    (recipe_id, 'used', 'rice vinegar', '2 tbsp'),
    (recipe_id, 'used', 'asian pear, sliced', '1/2'),
    (recipe_id, 'used', 'cucumber, julienned', '1'),
    (recipe_id, 'used', 'boiled egg', '2'),
    (recipe_id, 'used', 'korean mustard', 'to taste');
END $$;

-- ─── Recipe 74: Galbitang ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000074';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Galbitang',
    'A clear, deeply nourishing beef short rib soup simmered for hours with radish and garlic until the meat falls off the bone.',
    90, 4,
    ARRAY[
      'Soak the short ribs in cold water for 1 hour, changing the water once, to remove excess blood.',
      'Blanch the ribs in boiling water for 5 minutes, then drain and rinse off any scum.',
      'Place the ribs in a large pot with fresh water, the whole garlic cloves, and onion, and bring to a boil.',
      'Reduce to a gentle simmer and cook for about 1.5 hours, skimming any foam that rises to the surface.',
      'Add the sliced radish and continue simmering for another 30 minutes until the radish is tender and the broth is rich.',
      'If using glass noodles, add them during the last 5 minutes of cooking to soften.',
      'Season the broth with salt and pepper to taste, then ladle into bowls and top with chopped scallions before serving.'
    ],
    'korean', true, 360, 28, 12, 20, 'any', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/galbitang.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef short ribs', '1kg'),
    (recipe_id, 'used', 'korean radish, sliced', '300g'),
    (recipe_id, 'used', 'garlic, whole cloves', '6'),
    (recipe_id, 'used', 'onion', '1'),
    (recipe_id, 'used', 'scallions, chopped', '2'),
    (recipe_id, 'used', 'glass noodles (optional)', '50g'),
    (recipe_id, 'used', 'salt', 'to taste'),
    (recipe_id, 'used', 'black pepper', 'to taste');
END $$;

-- ─── Recipe 75: Dak Galbi ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000075';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Dak Galbi',
    'Spicy stir-fried chicken thigh with chewy rice cakes, cabbage, and sweet potato, sizzled together in a fiery gochujang glaze.',
    40, 4,
    ARRAY[
      'Combine the gochujang, gochugaru, soy sauce, and minced garlic into a thick marinade paste.',
      'Toss the cubed chicken thigh in the marinade and let it sit for at least 30 minutes.',
      'Heat a wide, flat pan and add the marinated chicken along with any remaining marinade.',
      'Add the sliced sweet potato and cook for a few minutes until the chicken begins to color.',
      'Add the rice cakes and chopped cabbage, tossing everything together over high heat.',
      'Continue stir-frying for 8-10 minutes until the chicken is fully cooked and the vegetables are tender-crisp.',
      'Stir in the scallions during the last minute of cooking and serve straight from the pan.'
    ],
    'korean', true, 430, 30, 30, 18, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/dak-galbi.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'boneless chicken thigh, cubed', '700g'),
    (recipe_id, 'used', 'gochujang', '3 tbsp'),
    (recipe_id, 'used', 'gochugaru', '1 tbsp'),
    (recipe_id, 'used', 'soy sauce', '2 tbsp'),
    (recipe_id, 'used', 'garlic, minced', '3 cloves'),
    (recipe_id, 'used', 'korean rice cakes', '200g'),
    (recipe_id, 'used', 'cabbage, chopped', '2 cups'),
    (recipe_id, 'used', 'sweet potato, sliced', '1'),
    (recipe_id, 'used', 'scallions, chopped', '3');
END $$;

-- ─── Recipe 76: Ojingeo Bokkeum ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000076';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Ojingeo Bokkeum',
    'Tender squid and crisp vegetables tossed quickly over high heat in a spicy, glossy gochujang sauce.',
    25, 2,
    ARRAY[
      'Score the squid bodies in a shallow crosshatch pattern, then cut into bite-sized pieces.',
      'Whisk together the gochujang, gochugaru, soy sauce, sugar, and minced garlic to make the sauce.',
      'Heat oil in a wok or large pan over high heat and stir-fry the onion and carrot for 2 minutes until just softened.',
      'Add the squid pieces and stir-fry quickly for 1-2 minutes, taking care not to overcook it.',
      'Pour in the prepared sauce and toss everything together over high heat until the squid and vegetables are evenly coated.',
      'Cook for another 2 minutes until the sauce thickens slightly and clings to the squid.',
      'Finish with a drizzle of sesame oil and the chopped scallions, tossing once more before serving hot.'
    ],
    'korean', true, 310, 26, 22, 10, 'pescatarian', ARRAY['Dairy-Free', 'Nut-Free'],
    '00000000-0000-0000-0000-000000555570/ojingeo-bokkeum.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'squid, cleaned and sliced', '400g'),
    (recipe_id, 'used', 'gochujang', '2 tbsp'),
    (recipe_id, 'used', 'gochugaru', '1 tbsp'),
    (recipe_id, 'used', 'soy sauce', '1 tbsp'),
    (recipe_id, 'used', 'sugar', '1 tbsp'),
    (recipe_id, 'used', 'garlic, minced', '2 cloves'),
    (recipe_id, 'used', 'onion, sliced', '1'),
    (recipe_id, 'used', 'carrot, sliced', '1/2'),
    (recipe_id, 'used', 'scallions, chopped', '2'),
    (recipe_id, 'used', 'sesame oil', '1 tbsp');
END $$;

-- ─── Recipe 77: Bossam ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000077';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Bossam',
    'Tender simmered pork belly sliced thin and wrapped in cool napa cabbage leaves with ssamjang and fresh kimchi.',
    90, 4,
    ARRAY[
      'Place the pork in a large pot with enough water to cover it, along with the doenjang, garlic, ginger, and bay leaves.',
      'Bring to a boil, then reduce to a simmer and cook for 1 to 1.5 hours until the pork is fork-tender.',
      'Test for doneness by piercing with a chopstick; it should slide in easily with no resistance.',
      'Remove the pork and let it rest for 10 minutes before slicing it into thin pieces.',
      'Blanch the napa cabbage leaves briefly in the hot cooking liquid until just softened, then drain.',
      'Arrange the sliced pork on a platter alongside the softened cabbage leaves, ssamjang, and fresh kimchi.',
      'To eat, wrap a slice of pork with a dab of ssamjang and a bit of kimchi inside a cabbage leaf.'
    ],
    'korean', true, 450, 32, 8, 30, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/bossam.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'pork belly or pork shoulder, whole piece', '1kg'),
    (recipe_id, 'used', 'doenjang', '2 tbsp'),
    (recipe_id, 'used', 'garlic, whole cloves', '8'),
    (recipe_id, 'used', 'ginger, sliced', '1 knob'),
    (recipe_id, 'used', 'bay leaves', '2'),
    (recipe_id, 'used', 'napa cabbage leaves', 'for wrapping'),
    (recipe_id, 'used', 'ssamjang', 'for serving'),
    (recipe_id, 'used', 'fresh kimchi', 'for serving');
END $$;

-- ─── Recipe 78: Kalguksu ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000078';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Kalguksu',
    'Hand-cut wheat noodles simmered in a savory clam and anchovy broth with tender zucchini, a warming bowl of comfort.',
    45, 3,
    ARRAY[
      'Simmer the anchovy stock with the kelp for 15 minutes, then remove the kelp and discard.',
      'Add the clams to the stock and cook until they open, discarding any that remain closed.',
      'Stir in the minced garlic, sliced onion, and soy sauce, and simmer for a few more minutes.',
      'Bring a separate pot of water to a boil and cook the hand-cut wheat noodles until tender, stirring occasionally to prevent sticking.',
      'Drain the noodles and rinse briefly under warm water to remove excess starch.',
      'Divide the noodles among serving bowls and ladle the hot clam broth over the top, distributing the clams evenly.',
      'Add the julienned zucchini on top of the hot broth so it wilts slightly, then garnish with scallions before serving.'
    ],
    'korean', true, 380, 16, 62, 6, 'pescatarian', ARRAY['Dairy-Free', 'Nut-Free'],
    '00000000-0000-0000-0000-000000555570/kalguksu.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'wheat noodles, hand-cut', '500g'),
    (recipe_id, 'used', 'clams', '300g'),
    (recipe_id, 'used', 'anchovy stock', '5 cups'),
    (recipe_id, 'used', 'kelp', '1 piece'),
    (recipe_id, 'used', 'zucchini, julienned', '1/2'),
    (recipe_id, 'used', 'onion, sliced', '1/2'),
    (recipe_id, 'used', 'garlic, minced', '2 cloves'),
    (recipe_id, 'used', 'soy sauce', '1 tbsp'),
    (recipe_id, 'used', 'scallions, chopped', '2');
END $$;

-- ─── Recipe 79: Samgyetang ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000079';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Samgyetang',
    'A whole young chicken stuffed with glutinous rice and ginseng, simmered until meltingly tender in a restorative, mild broth.',
    100, 2,
    ARRAY[
      'Rinse the chicken cavity thoroughly and pat it dry inside and out.',
      'Stuff the cavity with the soaked glutinous rice, ginseng root, half the jujubes, half the garlic cloves, and the chestnuts, securing the opening with a toothpick or kitchen string if needed.',
      'Place the stuffed chicken in a deep pot and add enough water to fully submerge it, along with the remaining garlic and jujubes.',
      'Bring to a boil, then skim off any foam and reduce to a gentle simmer.',
      'Cover and cook for 1 to 1.5 hours, until the chicken is completely tender and the rice inside is fully cooked.',
      'Check occasionally and top up with hot water if the level drops too low.',
      'Ladle the chicken and broth into a deep bowl and season at the table with salt and pepper to taste.'
    ],
    'korean', true, 520, 40, 35, 20, 'any', ARRAY['Gluten-Free', 'Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/samgyetang.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'whole small chicken (cornish hen size)', '1'),
    (recipe_id, 'used', 'glutinous rice, soaked', '1/2 cup'),
    (recipe_id, 'used', 'fresh ginseng root', '1'),
    (recipe_id, 'used', 'dried jujubes', '4'),
    (recipe_id, 'used', 'garlic, whole cloves', '6'),
    (recipe_id, 'used', 'chestnuts, peeled', '4'),
    (recipe_id, 'used', 'water', '6 cups'),
    (recipe_id, 'used', 'salt and pepper', 'to taste');
END $$;

-- ─── Recipe 80: Yukgaejang ──────────────────────────────────────────
DO $$
DECLARE recipe_id UUID := 'a0000001-0000-4000-8000-000000000080';
BEGIN
  INSERT INTO public.recipes (id, created_by, title, summary, time_minutes, servings, steps, cuisine, is_user_shared, calories, protein_g, carbs_g, fat_g, diet_type, dietary_restrictions, image_path)
  VALUES (recipe_id, '00000000-0000-0000-0000-000000555570',
    'Yukgaejang',
    'A robust, fiery-red shredded beef soup loaded with fernbrake and bean sprouts, simmered low and slow for deep, savory flavor.',
    90, 4,
    ARRAY[
      'Simmer the beef brisket in water for about 1 hour until tender, then remove and shred it into bite-sized strips once cool enough to handle, reserving the cooking liquid.',
      'Heat sesame oil in a large pot and stir-fry the gochugaru and minced garlic briefly until fragrant, being careful not to burn it.',
      'Add the shredded beef back in along with the soaked fernbrake, and stir-fry for a few minutes to coat everything in the chili oil.',
      'Pour in the reserved beef broth and bring to a boil.',
      'Add the soy sauce and simmer for 20 minutes to let the flavors meld.',
      'Add the bean sprouts and scallions and continue simmering for another 10 minutes until the vegetables are tender but not mushy.',
      'Skim any excess oil from the surface, taste and adjust seasoning with more soy sauce or salt, then serve hot.'
    ],
    'korean', true, 330, 24, 20, 16, 'any', ARRAY['Dairy-Free', 'Nut-Free', 'Shellfish-Free'],
    '00000000-0000-0000-0000-000000555570/yukgaejang.jpg');
  INSERT INTO public.recipe_ingredients (recipe_id, kind, name, quantity) VALUES
    (recipe_id, 'used', 'beef brisket', '400g'),
    (recipe_id, 'used', 'gochugaru', '3 tbsp'),
    (recipe_id, 'used', 'soy sauce', '2 tbsp'),
    (recipe_id, 'used', 'garlic, minced', '4 cloves'),
    (recipe_id, 'used', 'fernbrake (gosari), soaked', '1 cup'),
    (recipe_id, 'used', 'bean sprouts', '2 cups'),
    (recipe_id, 'used', 'scallions, cut into long pieces', '6'),
    (recipe_id, 'used', 'sesame oil', '2 tbsp'),
    (recipe_id, 'used', 'water', '8 cups');
END $$;
