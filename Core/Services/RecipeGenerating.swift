import Foundation

protocol RecipeGenerating {
    func generateRecipes(for ingredientNames: [String], options: GenerationOptions, count: Int) async throws -> [Recipe]

    /// Snap Chef — one recipe from a confirmed ingredient list, plus the re-roll budget state.
    /// `isRegeneration` maps to the edge function's `snap_chef_regenerate` intent (2 free re-rolls
    /// per recipe before it starts consuming the daily quota).
    func snapChefRecipe(for ingredientNames: [String], options: GenerationOptions, isRegeneration: Bool) async throws -> SnapChefGeneration
}

extension RecipeGenerating {
    func generateRecipes(for ingredientNames: [String], options: GenerationOptions) async throws -> [Recipe] {
        try await generateRecipes(for: ingredientNames, options: options, count: recipesPerGeneration)
    }
}

struct SnapChefGeneration {
    let recipe: Recipe
    /// Free re-rolls left for this recipe (0–2). Prefer this over any client-side counter.
    let freeRegensRemaining: Int
    /// True when this call used one of the user's 5 daily generations.
    let countedAgainstDailyLimit: Bool
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
