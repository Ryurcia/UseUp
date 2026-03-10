import Foundation

protocol RecipeGenerating {
    func generateRecipes(for ingredientNames: [String], options: GenerationOptions) async throws -> [Recipe]
}

enum RecipeGenerationError: LocalizedError {
    case noIngredients

    var errorDescription: String? {
        switch self {
        case .noIngredients:
            return "Add at least one ingredient to generate recipes."
        }
    }
}
