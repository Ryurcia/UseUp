import Foundation

struct AIRecipeResponse: Codable {
    let recipes: [AIRecipe]
    /// Snap Chef only — how many free re-rolls remain for the current recipe, and whether this
    /// call consumed a daily generation. Absent (nil) for standard generation.
    let freeRegensRemaining: Int?
    let countedAgainstDailyLimit: Bool?
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

    enum CodingKeys: String, CodingKey {
        case title, summary, servings, cuisine, steps, macros, substitutions
        case timeMinutes = "time_minutes"
        case ingredientsUsed = "ingredients_used"
        case missingIngredients = "missing_ingredients"
    }

    func toRecipe() -> Recipe {
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
