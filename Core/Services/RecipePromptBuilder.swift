import Foundation

enum RecipePromptBuilder {

    static func buildSystemPrompt() -> String {
        """
        You are a recipe generation assistant. Return ONLY valid JSON, no markdown fences or extra text.

        Generate exactly 3 unique recipes using the user's available ingredients. Prioritize using the provided ingredients and minimize missing ingredients.

        Response JSON schema:
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
              }
            }
          ]
        }

        Valid cuisine values: american, asian, chinese, filipino, french, greek, indian, italian, japanese, korean, mediterranean, mexican, middleEastern, thai, other

        Rules:
        - Macros should be realistic per-serving estimates.
        - Steps should be concise and actionable, 4-8 steps per recipe.
        - cuisine must be exactly one of the valid values listed above.
        - Each recipe must have a distinct style or cuisine.
        """
    }

    static func buildUserPrompt(ingredientNames: [String], options: GenerationOptions) -> String {
        var lines: [String] = []

        lines.append("Ingredients available: \(ingredientNames.joined(separator: ", "))")

        if options.dietType != .any {
            lines.append("Diet type: \(options.dietType.rawValue)")
        }

        if !options.dietaryRestrictions.isEmpty {
            let restrictions = options.dietaryRestrictions.map(\.rawValue).sorted().joined(separator: ", ")
            lines.append("Dietary restrictions: \(restrictions)")
        }

        lines.append("Max cooking time: \(options.maxTimeMinutes) minutes")

        if let cuisine = options.cuisine {
            lines.append("Preferred cuisine: \(cuisine.rawValue)")
        }

        return lines.joined(separator: "\n")
    }
}
