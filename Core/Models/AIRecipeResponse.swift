import Foundation

struct AIRecipeResponse: Codable {
    let recipes: [AIRecipe]
}

struct AIRecipe: Codable {
    let title: String
    let summary: String
    let timeMinutes: Int
    let servings: Int
    let cuisine: String
    let ingredientsUsed: [AIIngredient]
    let missingIngredients: [AIIngredient]
    let steps: [String]
    let macros: AIMacros
    let substitutions: [AISubstitution]?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case title, summary, servings, cuisine, steps, macros, substitutions, tags
        case timeMinutes = "time_minutes"
        case ingredientsUsed = "ingredients_used"
        case missingIngredients = "missing_ingredients"
    }

    /// `dietType`/`dietaryRestrictions` come from the `GenerationOptions` the request was
    /// made with, not the LLM response — the response schema doesn't echo them back, but
    /// the prompt already instructs Gemini to honor them as hard constraints, so the
    /// request-time options are the source of truth for what got persisted.
    func toRecipe(dietType: String, dietaryRestrictions: [String]) -> Recipe {
        let recipeCuisine = Cuisine(databaseValue: cuisine) ?? .other

        let used = ingredientsUsed.map {
            RecipeIngredient(name: $0.name, quantity: $0.quantity)
        }

        let missing = missingIngredients.map {
            RecipeIngredient(name: $0.name, quantity: $0.quantity)
        }

        let recipeMacros = Macros(
            calories: macros.calories,
            proteinG: macros.proteinG,
            carbsG: macros.carbsG,
            fatG: macros.fatG
        )

        let subs = (substitutions ?? []).map {
            RecipeSubstitution(ingredient: $0.ingredient, substitute: $0.substitute, note: $0.note)
        }

        let deterministicTags = Recipe.deterministicTags(
            timeMinutes: timeMinutes,
            calories: macros.calories,
            proteinG: macros.proteinG
        )
        var mergedTags: [String] = []
        for tag in deterministicTags + (tags ?? []) where !mergedTags.contains(tag) {
            mergedTags.append(tag)
        }

        return Recipe(
            title: title,
            summary: summary,
            timeMinutes: timeMinutes,
            servings: servings,
            ingredientsUsed: used,
            missingIngredients: missing,
            steps: steps,
            macros: recipeMacros,
            sources: [],
            isUserShared: false,
            cuisine: recipeCuisine,
            rating: 0,
            dietType: dietType,
            dietaryRestrictions: dietaryRestrictions,
            tags: mergedTags,
            isAIGenerated: true,
            substitutions: subs
        )
    }
}

struct AISubstitution: Codable {
    let ingredient: String
    let substitute: String
    let note: String
}

struct AIIngredient: Codable {
    let name: String
    let quantity: String
}

struct AIMacros: Codable {
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int

    enum CodingKeys: String, CodingKey {
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
    }
}
