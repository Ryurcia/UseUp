// Pure prompt construction — no network, no Deno.serve — so the unit tests can import it without
// starting the edge-function server. `index.ts` is the only other importer.

export const RECIPES_PER_GENERATION = 5

// Source of truth for the recipe-generation system prompt (was the app's
// `RecipePromptBuilder.systemPrompt`). Edit here + redeploy; the hash in index.ts changes and a
// fresh Gemini cache is created automatically.
export const SYSTEM_PROMPT = `You are a professional chef and recipe curator. Your job is to generate recipes based on user-provided ingredients, preferences, and constraints.

 CRITICAL CONSTRAINTS (highest priority):
            - Return exactly the number of recipes requested in the user message — no more, no fewer.
            - Strictly follow dietary restrictions — never include restricted ingredients, even in suggested additions.

Respond ONLY with valid JSON matching this exact structure — no markdown, no backticks, no preamble:
{
  "recipes": [
    {
      "title": "string — recipe name",
      "summary": "string — one-sentence description",
      "time_minutes": "integer — total cook time in minutes",
      "servings": "integer — number of servings",
      "cuisine": "string — one of the valid cuisine values below",
      "ingredients_used": [
        { "name": "string", "quantity": "string e.g. 200g, 2 tbsp" }
      ],
      "missing_ingredients": [
        { "name": "string", "quantity": "string" }
      ],
      "steps": ["string — concise actionable step"],
      "macros": {
        "calories": "integer — per serving",
        "protein_g": "integer — grams per serving",
        "carbs_g": "integer — grams per serving",
        "fat_g": "integer — grams per serving"
      },
      "substitutions": [
        { "ingredient": "string — exact name of a missing_ingredient", "substitute": "string — practical replacement", "note": "string — one-sentence reason or tip" }
      ]
    }
  ]
}

Valid cuisine values: american, asian, chinese, filipino, french, greek, indian, italian, japanese, korean, mediterranean, mexican, middleEastern, thai, spanish, vietnamese, brazilian, ethiopian, turkish, peruvian, caribbean, other

Core rules:
           - Every recipe must be realistic and cookable by a home cook with standard kitchen equipment
           - Measurements must be precise — never "some"/"a handful"/"to taste"; give specific amounts, even for seasonings (e.g. "1/2 tsp salt")
           - Each step must be a single action or tightly related pair of actions. Include cooking temperatures in both °F and °C (e.g. "375°F / 190°C"), specific timing (e.g. "sauté 4-5 minutes"), and at least one visual or sensory cue (e.g. "until edges are golden brown", "until fragrant, about 30 seconds"). Aim for 5-12 steps per recipe. Do not skip obvious sub-steps like "preheat oven" or "bring water to a boil."
           - Flavor combinations must make culinary sense — do not force incompatible ingredients together
           - Group incompatible ingredients into separate recipes rather than forcing them together. Don't build a recipe around a single orphaned ingredient; list it in "unused_ingredients" with a brief pairing suggestion instead.
           - You may add up to 3 pantry staples (salt, pepper, oil, butter, garlic, common spices, basic condiments) as "missing_ingredients" to make the recipe work. Keep additions minimal.
           - Prep and cook times must be realistic for a home cook, not a professional kitchen — factor in actual chopping, measuring, and cleanup between steps.
           - Yield/servings must be reasonable for the recipe type (e.g. a stir-fry for 2-4, a casserole for 4-6)
           - Macro estimates should be conservative approximations based on standard nutritional values — rough estimates, not precise calculations. Round calories and fat up, protein down, when uncertain.
           - "substitutions" must only reference "missing_ingredients", never "ingredients_used". Provide one where a practical alternative exists; omit pantry staples with no viable substitute (e.g. water, salt). Keep notes to one sentence, and apply the same allergy/dietary-restriction/diet-type constraints as everywhere else — zero exceptions.`

export interface GenerationOptions {
  dietType: string
  dietaryRestrictions: string[]
  allergies: string[]
  maxTimeMinutes: number
  targetCalories: number | null
  cuisine: string | null
  skillLevel: number
  priorityIngredients: string[]
  diversifyIngredients: boolean
  // How many recipes to return. Standard generation = RECIPES_PER_GENERATION; Snap Chef = 1.
  count: number
}

export function normalizeOptions(o: Partial<GenerationOptions> | undefined): GenerationOptions {
  const count = o?.count
  return {
    dietType: o?.dietType ?? 'Any',
    dietaryRestrictions: o?.dietaryRestrictions ?? [],
    allergies: o?.allergies ?? [],
    maxTimeMinutes: o?.maxTimeMinutes ?? 30,
    targetCalories: o?.targetCalories ?? null,
    cuisine: o?.cuisine ?? null,
    skillLevel: o?.skillLevel ?? 1,
    priorityIngredients: o?.priorityIngredients ?? [],
    diversifyIngredients: o?.diversifyIngredients ?? false,
    count: typeof count === 'number' && count >= 1 && count <= RECIPES_PER_GENERATION
      ? Math.floor(count)
      : RECIPES_PER_GENERATION,
  }
}

// Port of the app's former `RecipePromptBuilder.buildUserPrompt`. The allergy / dietary-restriction
// lines are copied verbatim — they are safety-critical. See index.test.ts.
export function buildUserPrompt(ingredientNames: string[], o: GenerationOptions): string {
  const lines: string[] = []

  lines.push(`Ingredients to use up (with available quantities): ${ingredientNames.join(', ')}`)
  lines.push(
    'Use ALL of the listed ingredients and consume as much of each quantity as possible. Scale the number of servings so that the full amounts are used — if large quantities are listed, suggest a larger-batch recipe.',
  )
  if (o.count === 1) {
    lines.push(
      'Generate exactly 1 recipe in "recipes" — no more, no fewer. Return the single best dish that can be made from these ingredients.',
    )
  } else {
    lines.push(
      `Generate exactly ${o.count} recipes in "recipes" — no more, no fewer. This overrides ingredient-splitting logic: consolidate into the ${o.count} strongest combinations if grouping would yield more, or add variations from the same ingredient pool if fewer.`,
    )
  }
  const minIngredients = Math.min(o.diversifyIngredients ? 2 : 3, ingredientNames.length)
  lines.push(`Each recipe must use at least ${minIngredients} user-provided ingredient${minIngredients === 1 ? '' : 's'}.`)

  if (o.diversifyIngredients) {
    lines.push(
      'Each recipe should use a DIFFERENT SUBSET of the provided ingredients. You do NOT need to use all ingredients in every recipe — variety is the goal. Different recipes can share some ingredients, but each recipe should explore a distinct combination. Prioritize ingredient diversity across the recipe set.',
    )
    lines.push(
      'Recipe style: Each recipe should use a DIFFERENT combination of the provided ingredients. Do not repeat the same set of ingredients across recipes.',
    )
  } else {
    lines.push(
      "Each recipe must use at least 60% of the user's provided ingredients. Prioritize recipes that maximize use of provided ingredients.",
    )
  }

  if (o.priorityIngredients.length > 0) {
    lines.push(
      `Priority ingredients (expiring soon — include in as many recipes as possible): ${o.priorityIngredients.join(', ')}`,
    )
  }

  if (o.dietType !== 'Any') {
    lines.push(`Diet type: ${o.dietType}`)
  }

  if (o.dietaryRestrictions.length > 0) {
    const restrictions = [...o.dietaryRestrictions].sort().join(', ')
    lines.push(`Dietary restrictions: ${restrictions}`)
  }

  if (o.allergies.length > 0) {
    lines.push(
      `⚠️ CRITICAL ALLERGY ALERT — THIS IS A HARD CONSTRAINT, NOT A PREFERENCE:
The user is allergic to: ${o.allergies.join(', ')}
You MUST NOT include any of these allergens in ANY ingredient — treat it as life-or-death. Never include any allergen in any part of any recipe — not in ingredients_used, missing_ingredients, steps, garnishes, sauces, or cooking fats. Also exclude common derivatives and hidden sources of the allergen (e.g., if allergic to dairy, also exclude whey, casein, ghee, cream, butter). There are zero exceptions.
Do NOT suggest any ingredient that may contain traces of these allergens.
Violating this constraint could cause a severe allergic reaction. There are no exceptions.`,
    )
  }

  if (o.maxTimeMinutes < 60) {
    lines.push(`Max cooking time: ${o.maxTimeMinutes} minutes`)
  }

  if (o.targetCalories != null) {
    lines.push(`Target calories per serving: ${o.targetCalories}`)
  }

  if (o.cuisine) {
    lines.push(
      `Required cuisine: ${o.cuisine} — every recipe MUST be an authentic ${o.cuisine} dish. Do not mix cuisines or use ingredients/techniques foreign to this tradition.`,
    )
  }

  let skillDescription: string
  switch (o.skillLevel) {
    case 1:
      skillDescription =
        'beginner — keep recipes simple with basic techniques, minimal steps, and common pantry-friendly methods (boiling, pan-frying, baking)'
      break
    case 2:
      skillDescription =
        'intermediate — comfortable with most cooking techniques, can handle multi-step recipes and moderate complexity'
      break
    default:
      skillDescription =
        'advanced — experienced cook, feel free to include complex techniques, layered flavors, and ambitious preparations'
  }
  lines.push(`Cooking skill level: ${skillDescription}`)

  return lines.join('\n')
}
