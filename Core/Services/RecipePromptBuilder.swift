import Foundation

enum RecipePromptBuilder {

    static func buildSystemPrompt(recipeCount: Int = 3) -> String {
        """
        You are a professional chef and recipe developer. Your job is to generate exactly \(recipeCount) recipe\(recipeCount == 1 ? "" : "s") based on user-provided ingredients, preferences, and constraints.

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
              "dietary_restrictions": ["string — zero or more of: Gluten-Free, Nut-Free, Dairy-Free, Soy-Free, Egg-Free, Shellfish-Free, Low Sodium"]
            }
          ]
        }

        Valid cuisine values: american, asian, chinese, filipino, french, greek, indian, italian, japanese, korean, mediterranean, mexican, middleEastern, thai, spanish, vietnamese, brazilian, ethiopian, turkish, peruvian, caribbean, other
        
        Core rules:
            - Every recipe must be realistic and cookable by a home cook
            - Measurements must be precise and accurate (no vague amounts)
            - Cooking steps must be in logical order with correct timing
            - Flavor combinations must make sense — do not force ingredients together if they clash
            - If the user provides random or mismatched ingredients, find the best possible recipe that uses as many as possible. It's okay to skip ingredients that genuinely don't work. Note which provided ingredients were excluded and why.
            - You may suggest up to 3 additional pantry staples (salt, pepper, oil, butter, garlic, common spices, etc.) to make the recipe work, but keep additions minimal
            - Prep times and cook times must be realistic, not aspirational
            - Yield/servings must be reasonable for the recipe type

            When given dietary restrictions, strictly follow them. Never include restricted ingredients, even in suggested additions.
            - You MUST return exactly \(recipeCount) recipe\(recipeCount == 1 ? "" : "s") in the "recipes" array — no more, no fewer.
            - For each recipe, the number of items in "ingredients_used" MUST be greater than 40% of the total ingredients (ingredients_used + missing_ingredients combined). Prioritise recipes that make the most use of the provided ingredients.
        """
    }

    static func buildUserPrompt(ingredientNames: [String], options: GenerationOptions) -> String {
        var lines: [String] = []

        lines.append("Ingredients available (name, amount if known): \(ingredientNames.joined(separator: ", "))")

        if options.dietType != .any {
            lines.append("Diet type: \(options.dietType.rawValue)")
        }

        if !options.dietaryRestrictions.isEmpty {
            let restrictions = options.dietaryRestrictions.map(\.rawValue).sorted().joined(separator: ", ")
            lines.append("Dietary restrictions: \(restrictions)")
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
