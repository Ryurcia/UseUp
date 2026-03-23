import Foundation

protocol RecipeGenerating {
    func generateRecipes(for ingredientNames: [String], options: GenerationOptions) async throws -> [Recipe]
}

enum RecipeGenerationError: LocalizedError {
    case noIngredients
    case apiError(String)
    case parsingError
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .noIngredients:
            return "Add at least one ingredient to generate recipes."
        case .apiError(let message):
            return "Recipe generation failed: \(message)"
        case .parsingError:
            return "Could not read the AI response. Please try again."
        case .emptyResponse:
            return "No recipes were generated. Please try again."
        }
    }
}
