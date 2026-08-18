import Foundation

enum RecipePromptBuilder {

    static func buildSystemPrompt(recipeCount: Int = 3, diversify: Bool = false) -> String {
        """
        You are a professional chef and recipe curator. Your job is to generate exactly \(recipeCount) recipe\(recipeCount == 1 ? "" : "s") based on user-provided ingredients, preferences, and constraints.

         CRITICAL CONSTRAINTS (highest priority):
                    - You MUST return exactly \(recipeCount) recipe\(recipeCount == 1 ? "" : "s") in the "recipes" array — no more, no fewer. This count takes absolute priority over ingredient-splitting logic. If natural grouping would produce more recipes, consolidate into the \(recipeCount) strongest combinations. If fewer, create additional variations from the same ingredient pool.
                    - When given dietary restrictions, strictly follow them. Never include restricted ingredients, even in suggested additions.

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
              "diet_type": "string — one of: any, vegetarian, vegan, pescatarian, keto, paleo",
              "dietary_restrictions": ["string — zero or more of: Gluten-Free, Nut-Free, Dairy-Free, Soy-Free, Egg-Free, Shellfish-Free, Low Sodium"],
              "substitutions": [
                { "ingredient": "string — exact name of a missing_ingredient", "substitute": "string — practical replacement", "note": "string — one-sentence reason or tip" }
              ]
            }
          ]
        }

        Valid cuisine values: american, asian, chinese, filipino, french, greek, indian, italian, japanese, korean, mediterranean, mexican, middleEastern, thai, spanish, vietnamese, brazilian, ethiopian, turkish, peruvian, caribbean, other
        
        Core rules:
                   - Every recipe must be realistic and cookable by a home cook with standard kitchen equipment
                   - Measurements must be precise (no "some", "a handful", "to taste" — give a specific starting amount even for seasonings, e.g. "1/2 tsp salt")
                   - Each step must be a single action or tightly related pair of actions. Include cooking temperatures in both °F and °C (e.g. "375°F / 190°C"), specific timing (e.g. "sauté 4-5 minutes"), and at least one visual or sensory cue (e.g. "until edges are golden brown", "until fragrant, about 30 seconds"). Aim for 5-12 steps per recipe. Do not skip obvious sub-steps like "preheat oven" or "bring water to a boil."
                   - Flavor combinations must make culinary sense — do not force incompatible ingredients together
                   - If some provided ingredients don't combine well into a single cohesive dish, group compatible ingredients into separate recipes. Each recipe should use at least \(diversify ? 2 : 3) user-provided ingredients. Do not build a recipe around a single orphaned ingredient — instead, list it in "unused_ingredients" with a brief pairing suggestion.
                   - You may add up to 3 pantry staples (salt, pepper, oil, butter, garlic, common spices, basic condiments) as "missing_ingredients" to make the recipe work. Keep additions minimal.
                   - \(diversify ? "Each recipe should use a DIFFERENT SUBSET of the provided ingredients. You do NOT need to use all ingredients in every recipe — variety is the goal. Different recipes can share some ingredients, but each recipe should explore a distinct combination. Prioritize ingredient diversity across the recipe set." : "Each recipe must use at least 60% of the user's provided ingredients. Prioritize recipes that maximize use of provided ingredients.")
                   - Prep times and cook times must be realistic for a home cook, not a professional kitchen. Factor in actual chopping, measuring, and cleanup between steps.
                   - Yield/servings must be reasonable for the recipe type (e.g. a stir-fry for 2-4, a casserole for 4-6)
                   - Macro estimates should be conservative approximations based on standard nutritional values. These are rough estimates, not precise calculations. Round calories and fat up, protein down, when uncertain.
                   - "dietary_flags" should list ALL applicable flags for the recipe as-written, independent of "diet_type". A vegan recipe should also be flagged Dairy-Free and Egg-Free. Only include flags that are definitively true — do not guess.
                   - "substitutions" must only reference ingredients from "missing_ingredients" — never from "ingredients_used". Provide a substitution for each missing ingredient where a practical alternative exists. Omit entries for pantry staples with no viable substitute (e.g. water, salt). Keep notes to one sentence. Substitutes must never introduce allergens or violate the user's dietary restrictions or diet type — apply the same hard constraints to substitutions as to all other ingredients.
        """
    }

    static func buildUserPrompt(ingredientNames: [String], options: GenerationOptions) -> String {
        var lines: [String] = []

        lines.append("Ingredients to use up (with available quantities): \(ingredientNames.joined(separator: ", "))")
        lines.append("Use ALL of the listed ingredients and consume as much of each quantity as possible. Scale the number of servings so that the full amounts are used — if large quantities are listed, suggest a larger-batch recipe.")

        if !options.priorityIngredients.isEmpty {
            lines.append("Priority ingredients (expiring soon — include in as many recipes as possible): \(options.priorityIngredients.joined(separator: ", "))")
        }

        if options.diversifyIngredients {
            lines.append("Recipe style: Each recipe should use a DIFFERENT combination of the provided ingredients. Do not repeat the same set of ingredients across recipes.")
        }

        if options.dietType != .any {
            lines.append("Diet type: \(options.dietType.rawValue)")
        }

        if !options.dietaryRestrictions.isEmpty {
            let restrictions = options.dietaryRestrictions.map(\.rawValue).sorted().joined(separator: ", ")
            lines.append("Dietary restrictions: \(restrictions)")
        }

        if !options.allergies.isEmpty {
            let allergyList = options.allergies.joined(separator: ", ")
            lines.append("""
            ⚠️ CRITICAL ALLERGY ALERT — THIS IS A HARD CONSTRAINT, NOT A PREFERENCE:
            The user is allergic to: \(allergyList)
            You MUST NOT include any of these allergens in ANY ingredient — treat it as life-or-death. Never include any allergen in any part of any recipe — not in ingredients_used, missing_ingredients, steps, garnishes, sauces, or cooking fats. Also exclude common derivatives and hidden sources of the allergen (e.g., if allergic to dairy, also exclude whey, casein, ghee, cream, butter). There are zero exceptions.
            Do NOT suggest any ingredient that may contain traces of these allergens.
            Violating this constraint could cause a severe allergic reaction. There are no exceptions.
            """)
        }

        if options.maxTimeMinutes < 60 {
            lines.append("Max cooking time: \(options.maxTimeMinutes) minutes")
        }

        if let targetCalories = options.targetCalories {
            lines.append("Target calories per serving: \(targetCalories)")
        }

        if let cuisine = options.cuisine {
            lines.append("Required cuisine: \(cuisine.rawValue) — every recipe MUST be an authentic \(cuisine.rawValue) dish. Do not mix cuisines or use ingredients/techniques foreign to this tradition.")
        }

        let skillDescription: String
        switch options.skillLevel {
        case 1:
            skillDescription = "beginner — keep recipes simple with basic techniques, minimal steps, and common pantry-friendly methods (boiling, pan-frying, baking)"
        case 2:
            skillDescription = "intermediate — comfortable with most cooking techniques, can handle multi-step recipes and moderate complexity"
        default:
            skillDescription = "advanced — experienced cook, feel free to include complex techniques, layered flavors, and ambitious preparations"
        }
        lines.append("Cooking skill level: \(skillDescription)")

        return lines.joined(separator: "\n")
    }
}
