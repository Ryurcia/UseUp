import Foundation

protocol RecipeGenerating {
    func generateRecipes(for ingredientNames: [String], options: GenerationOptions, count: Int) async throws -> [Recipe]
}

extension RecipeGenerating {
    func generateRecipes(for ingredientNames: [String], options: GenerationOptions) async throws -> [Recipe] {
        try await generateRecipes(for: ingredientNames, options: options, count: recipesPerGeneration)
    }
}

/// Every generation request produces exactly this many recipes. The count is also baked into the
/// edge function's prompt (`supabase/functions/generate-recipes/prompt.ts` — `RECIPES_PER_GENERATION`);
/// keep the two in sync.
let recipesPerGeneration = 5

enum RecipeGenerationError: LocalizedError {
    case noIngredients
    case apiError(String)
    case parsingError
    case emptyResponse
    /// The server-side generation quota (5 per day) is used up.
    case limitExhausted

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
        case .limitExhausted:
            return "You've used all your recipe generations for now."
        }
    }
}
