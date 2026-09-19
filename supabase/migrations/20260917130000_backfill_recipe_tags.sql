-- One-time backfill of `tags` for the 100 seeded community recipes (Greek/Korean/
-- Ethiopian batches + the original 20-recipe seed) that predate the tags column and
-- had never had it populated. New recipes going forward get tags from
-- AIRecipe.toRecipe()'s deterministic+LLM merge (Core/Models/AIRecipeResponse.swift);
-- this is only for what already existed. Each row's tags combine the same deterministic
-- rules (quick/high-protein/low-calorie) with a hand-reviewed set of 2-4 qualitative
-- tags describing dish type and cooking method/vibe, deliberately not repeating cuisine
-- or dietary info that's already tracked in other columns.
--
-- recipes_search_vector_trigger (from 049_add_recipe_tags_and_search.sql) fires
-- `before update`, so search_vector refreshes automatically as a side effect of these
-- updates — no separate step needed.

update public.recipes set tags = ARRAY['high-protein','breakfast','bowl','meal-prep']::text[] where id = 'a0000001-0000-4000-8000-000000000025'; -- High-Protein Breakfast Bowl
update public.recipes set tags = ARRAY['high-protein','bowl','seafood','meal-prep']::text[] where id = 'a0000001-0000-4000-8000-000000000032'; -- High-Protein Salmon Bowl
update public.recipes set tags = ARRAY['high-protein','seafood','glazed','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000001'; -- Honey Garlic Salmon
update public.recipes set tags = ARRAY['soup','noodles','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000014'; -- Pho Bo
update public.recipes set tags = ARRAY['rice-bowl','glazed','slow-cooked']::text[] where id = 'a0000001-0000-4000-8000-000000000034'; -- Char Siu Pork Rice
update public.recipes set tags = ARRAY['spicy','comfort-food','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000008'; -- Mapo Tofu
update public.recipes set tags = ARRAY['soup','comfort-food','tangy']::text[] where id = 'a0000001-0000-4000-8000-000000000011'; -- Sinigang na Baboy
update public.recipes set tags = ARRAY['high-protein','stew','braise','slow-cooked','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000037'; -- Beef Bourguignon
update public.recipes set tags = ARRAY['low-calorie','stew','side-dish']::text[] where id = 'a0000001-0000-4000-8000-000000000009'; -- Classic Ratatouille
update public.recipes set tags = ARRAY['high-protein','braise','stew','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000020'; -- Coq au Vin
update public.recipes set tags = ARRAY['soup','comfort-food','slow-cooked']::text[] where id = 'a0000001-0000-4000-8000-000000000031'; -- French Onion Soup
update public.recipes set tags = ARRAY['soup','comfort-food','tangy']::text[] where id = 'a0000001-0000-4000-8000-000000000043'; -- Avgolemono Chicken Soup
update public.recipes set tags = ARRAY['bake','side-dish','roasted']::text[] where id = 'a0000001-0000-4000-8000-000000000045'; -- Briam Roasted Vegetable Bake
update public.recipes set tags = ARRAY['high-protein','skewers','grilled','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000010'; -- Chicken Souvlaki with Tzatziki
update public.recipes set tags = ARRAY['quick','salad','refreshing']::text[] where id = 'a0000001-0000-4000-8000-000000000049'; -- Dakos Cretan Barley Salad
update public.recipes set tags = ARRAY['soup','hearty','slow-cooked']::text[] where id = 'a0000001-0000-4000-8000-000000000047'; -- Fasolada White Bean Soup
update public.recipes set tags = ARRAY['dessert','pie','baked']::text[] where id = 'a0000001-0000-4000-8000-000000000059'; -- Galaktoboureko Custard Phyllo Pie
update public.recipes set tags = ARRAY['bake','stuffed','side-dish']::text[] where id = 'a0000001-0000-4000-8000-000000000044'; -- Gemista Stuffed Tomatoes and Peppers
update public.recipes set tags = ARRAY['bake','hearty','slow-cooked']::text[] where id = 'a0000001-0000-4000-8000-000000000050'; -- Gigantes Plaki Baked Giant Beans
update public.recipes set tags = ARRAY['casserole','comfort-food','bake']::text[] where id = 'a0000001-0000-4000-8000-000000000027'; -- Greek Moussaka
update public.recipes set tags = ARRAY['quick','salad','refreshing']::text[] where id = 'a0000001-0000-4000-8000-000000000046'; -- Horiatiki Village Salad with Feta
update public.recipes set tags = ARRAY['meatballs','fried','appetizer']::text[] where id = 'a0000001-0000-4000-8000-000000000048'; -- Keftedes Herbed Meatballs
update public.recipes set tags = ARRAY['fritters','fried','appetizer']::text[] where id = 'a0000001-0000-4000-8000-000000000058'; -- Kolokithokeftedes Zucchini Fritters
update public.recipes set tags = ARRAY['high-protein','grilled','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000052'; -- Lamb Chops with Oregano and Lemon
update public.recipes set tags = ARRAY['sausage','pan-fried','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000055'; -- Loukaniko with Peppers and Onions
update public.recipes set tags = ARRAY['low-calorie','dip','appetizer']::text[] where id = 'a0000001-0000-4000-8000-000000000056'; -- Melitzanosalata Smoky Eggplant Dip
update public.recipes set tags = ARRAY['casserole','comfort-food','bake']::text[] where id = 'a0000001-0000-4000-8000-000000000041'; -- Pastitsio
update public.recipes set tags = ARRAY['bake','seafood','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000053'; -- Psari Plaki Baked Fish with Tomatoes
update public.recipes set tags = ARRAY['stew','slow-cooked','hearty']::text[] where id = 'a0000001-0000-4000-8000-000000000054'; -- Revithada Chickpea Stew
update public.recipes set tags = ARRAY['quick','appetizer','pan-fried']::text[] where id = 'a0000001-0000-4000-8000-000000000051'; -- Saganaki Pan-Seared Cheese
update public.recipes set tags = ARRAY['meatballs','bake','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000060'; -- Soutzoukakia Baked Meatballs in Tomato Sauce
update public.recipes set tags = ARRAY['appetizer','baked','finger-food']::text[] where id = 'a0000001-0000-4000-8000-000000000042'; -- Spanakopita Triangles
update public.recipes set tags = ARRAY['bake','braise','comfort-food','slow-cooked']::text[] where id = 'a0000001-0000-4000-8000-000000000057'; -- Youvetsi Baked Orzo with Braised Lamb
update public.recipes set tags = ARRAY['high-protein','curry','comfort-food','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000005'; -- Butter Chicken
update public.recipes set tags = ARRAY['curry','budget-friendly','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000017'; -- Chana Masala
update public.recipes set tags = ARRAY['high-protein','curry','comfort-food','crowd-pleaser']::text[] where id = 'a0000001-0000-4000-8000-000000000022'; -- Chicken Tikka Masala
update public.recipes set tags = ARRAY['curry','comfort-food','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000035'; -- Palak Paneer
update public.recipes set tags = ARRAY['stew','budget-friendly','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000038'; -- Vegan Red Lentil Dal
update public.recipes set tags = ARRAY['pasta','weeknight','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000016'; -- Pasta alla Norma
update public.recipes set tags = ARRAY['pasta','comfort-food','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000021'; -- Spaghetti Carbonara
update public.recipes set tags = ARRAY['creamy','comfort-food','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000003'; -- Wild Mushroom Risotto
update public.recipes set tags = ARRAY['rice-bowl','comfort-food','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000018'; -- Gyudon
update public.recipes set tags = ARRAY['high-protein','seafood','glazed','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000033'; -- Miso Glazed Cod
update public.recipes set tags = ARRAY['high-protein','rice-bowl','glazed','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000004'; -- Teriyaki Chicken Donburi
update public.recipes set tags = ARRAY['soup','noodles','slow-cooked','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000030'; -- Tonkotsu Ramen
update public.recipes set tags = ARRAY['high-protein','sharing-plate','slow-cooked','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000077'; -- Bossam
update public.recipes set tags = ARRAY['hot-pot','stew','spicy','sharing-plate']::text[] where id = 'a0000001-0000-4000-8000-000000000069'; -- Budae Jjigae
update public.recipes set tags = ARRAY['high-protein','stir-fry','spicy','sharing-plate']::text[] where id = 'a0000001-0000-4000-8000-000000000075'; -- Dak Galbi
update public.recipes set tags = ARRAY['low-calorie','stew','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000067'; -- Doenjang Jjigae
update public.recipes set tags = ARRAY['rice-bowl','comfort-food','hearty']::text[] where id = 'a0000001-0000-4000-8000-000000000061'; -- Dolsot Bibimbap
update public.recipes set tags = ARRAY['soup','slow-cooked','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000074'; -- Galbitang
update public.recipes set tags = ARRAY['pancake','appetizer','sharing-plate','seafood']::text[] where id = 'a0000001-0000-4000-8000-000000000072'; -- Haemul Pajeon
update public.recipes set tags = ARRAY['noodles','comfort-food','hearty']::text[] where id = 'a0000001-0000-4000-8000-000000000070'; -- Jajangmyeon
update public.recipes set tags = ARRAY['noodles','side-dish','sharing-plate']::text[] where id = 'a0000001-0000-4000-8000-000000000062'; -- Japchae
update public.recipes set tags = ARRAY['soup','noodles','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000078'; -- Kalguksu
update public.recipes set tags = ARRAY['rice-bowl','spicy','weeknight','budget-friendly']::text[] where id = 'a0000001-0000-4000-8000-000000000066'; -- Kimchi Fried Rice
update public.recipes set tags = ARRAY['stew','spicy','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000007'; -- Kimchi Jjigae
update public.recipes set tags = ARRAY['grilled','glazed','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000024'; -- Korean Beef Bulgogi
update public.recipes set tags = ARRAY['high-protein','grilled','glazed','sharing-plate']::text[] where id = 'a0000001-0000-4000-8000-000000000071'; -- LA Galbi
update public.recipes set tags = ARRAY['noodles','cold-dish','refreshing']::text[] where id = 'a0000001-0000-4000-8000-000000000073'; -- Mul Naengmyeon
update public.recipes set tags = ARRAY['stir-fry','spicy','seafood']::text[] where id = 'a0000001-0000-4000-8000-000000000076'; -- Ojingeo Bokkeum
update public.recipes set tags = ARRAY['high-protein','soup','slow-cooked','hearty']::text[] where id = 'a0000001-0000-4000-8000-000000000079'; -- Samgyetang
update public.recipes set tags = ARRAY['street-food','spicy','sharing-plate']::text[] where id = 'a0000001-0000-4000-8000-000000000063'; -- Spicy Tteokbokki
update public.recipes set tags = ARRAY['hot-pot','stew','spicy','seafood']::text[] where id = 'a0000001-0000-4000-8000-000000000064'; -- Sundubu Jjigae
update public.recipes set tags = ARRAY['rolls','meal-prep','side-dish']::text[] where id = 'a0000001-0000-4000-8000-000000000065'; -- Vegetable Gimbap
update public.recipes set tags = ARRAY['high-protein','fried','glazed','sharing-plate']::text[] where id = 'a0000001-0000-4000-8000-000000000068'; -- Yangnyeom Dakgangjeong
update public.recipes set tags = ARRAY['soup','spicy','slow-cooked']::text[] where id = 'a0000001-0000-4000-8000-000000000080'; -- Yukgaejang
update public.recipes set tags = ARRAY['breakfast','one-pan','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000012'; -- Shakshuka
update public.recipes set tags = ARRAY['wrap','fried','budget-friendly']::text[] where id = 'a0000001-0000-4000-8000-000000000028'; -- Vegan Falafel Wrap
update public.recipes set tags = ARRAY['high-protein','tacos','slow-cooked','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000029'; -- Birria Tacos
update public.recipes set tags = ARRAY['tacos','street-food','grilled']::text[] where id = 'a0000001-0000-4000-8000-000000000002'; -- Carne Asada Street Tacos
update public.recipes set tags = ARRAY['high-protein','slow-cooked','comfort-food','tangy']::text[] where id = 'a0000001-0000-4000-8000-000000000015'; -- Crispy Carnitas
update public.recipes set tags = ARRAY['high-protein','bowl','grilled','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000013'; -- Chicken Shawarma Bowl
update public.recipes set tags = ARRAY['curry','comfort-food','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000006'; -- Green Curry with Chicken
update public.recipes set tags = ARRAY['quick','high-protein','stir-fry','spicy','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000019'; -- Pad Kra Pao
update public.recipes set tags = ARRAY['noodles','street-food','stir-fry']::text[] where id = 'a0000001-0000-4000-8000-000000000026'; -- Pad Thai
update public.recipes set tags = ARRAY['low-calorie','soup','spicy','tangy','seafood']::text[] where id = 'a0000001-0000-4000-8000-000000000036'; -- Tom Yum Goong
update public.recipes set tags = ARRAY['quick','breakfast','bowl','refreshing']::text[] where id = 'a0000001-0000-4000-8000-000000000040'; -- Açaí Smoothie Bowl
update public.recipes set tags = ARRAY['bowl','meal-prep','light']::text[] where id = 'a0000001-0000-4000-8000-000000000023'; -- Vegan Buddha Bowl
update public.recipes set tags = ARRAY['rice-bowl','seafood','sharing-plate']::text[] where id = 'a0000001-0000-4000-8000-000000000039'; -- Spanish Seafood Paella
update public.recipes set tags = ARRAY['low-calorie','side-dish','mild']::text[] where id = 'a0000001-0000-4000-8000-000000000088'; -- Atkilt Alicha
update public.recipes set tags = ARRAY['side-dish','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000093'; -- Ayib Begomen
update public.recipes set tags = ARRAY['salad','refreshing','tangy']::text[] where id = 'a0000001-0000-4000-8000-000000000095'; -- Azifa
update public.recipes set tags = ARRAY['sharing-plate','hearty','meal-prep']::text[] where id = 'a0000001-0000-4000-8000-000000000089'; -- Beyaynetu
update public.recipes set tags = ARRAY['dip','refreshing','tangy']::text[] where id = 'a0000001-0000-4000-8000-000000000100'; -- Buticha
update public.recipes set tags = ARRAY['breakfast','street-food','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000098'; -- Chechebsa
update public.recipes set tags = ARRAY['high-protein','stew','slow-cooked','mild']::text[] where id = 'a0000001-0000-4000-8000-000000000094'; -- Doro Alicha
update public.recipes set tags = ARRAY['high-protein','stew','slow-cooked','spicy','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000081'; -- Doro Wat
update public.recipes set tags = ARRAY['high-protein','pan-fried','spicy','hearty']::text[] where id = 'a0000001-0000-4000-8000-000000000090'; -- Dulet
update public.recipes set tags = ARRAY['low-calorie','side-dish','light']::text[] where id = 'a0000001-0000-4000-8000-000000000092'; -- Fosolia
update public.recipes set tags = ARRAY['breakfast','hearty','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000097'; -- Genfo
update public.recipes set tags = ARRAY['low-calorie','side-dish','slow-cooked']::text[] where id = 'a0000001-0000-4000-8000-000000000086'; -- Gomen
update public.recipes set tags = ARRAY['high-protein','appetizer','spiced','minimalist']::text[] where id = 'a0000001-0000-4000-8000-000000000096'; -- Gored Gored
update public.recipes set tags = ARRAY['high-protein','stew','slow-cooked','spicy','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000099'; -- Key Wat
update public.recipes set tags = ARRAY['high-protein','braise','slow-cooked','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000091'; -- Kikil
update public.recipes set tags = ARRAY['high-protein','spiced','bold','hearty']::text[] where id = 'a0000001-0000-4000-8000-000000000083'; -- Kitfo
update public.recipes set tags = ARRAY['stew','comfort-food','budget-friendly']::text[] where id = 'a0000001-0000-4000-8000-000000000082'; -- Misir Wat
update public.recipes set tags = ARRAY['stew','creamy','budget-friendly','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000085'; -- Shiro Wat
update public.recipes set tags = ARRAY['high-protein','stew','slow-cooked','spicy','comfort-food']::text[] where id = 'a0000001-0000-4000-8000-000000000087'; -- Yebeg Wat
update public.recipes set tags = ARRAY['high-protein','stir-fry','spiced','weeknight']::text[] where id = 'a0000001-0000-4000-8000-000000000084'; -- Zilzil Tibs
