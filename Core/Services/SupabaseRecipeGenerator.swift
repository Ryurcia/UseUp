import Foundation
import Supabase

/// Calls the `generate-recipes` Supabase edge function, which holds the Gemini API key, enforces
/// the generation quota, and serves the system prompt from a shared Gemini cache. The app only
/// sends structured ingredients + options; the function builds the prompt and calls Gemini.
final class SupabaseRecipeGenerator: RecipeGenerating {
    private let client = SupabaseManager.client

    func generateRecipes(for ingredientNames: [String], options: GenerationOptions, count: Int) async throws -> [Recipe] {
        let response = try await invoke(ingredientNames, options: options, count: count, intent: "standard")
        let recipes = response.recipes.prefix(count).map { $0.toRecipe() }
        guard !recipes.isEmpty else { throw RecipeGenerationError.emptyResponse }
        return recipes
    }

    func snapChefRecipe(for ingredientNames: [String], options: GenerationOptions, isRegeneration: Bool) async throws -> SnapChefGeneration {
        let response = try await invoke(
            ingredientNames,
            options: options,
            count: 1,
            intent: isRegeneration ? "snap_chef_regenerate" : "snap_chef"
        )
        guard let recipe = response.recipes.first?.toRecipe() else { throw RecipeGenerationError.emptyResponse }
        return SnapChefGeneration(
            recipe: recipe,
            freeRegensRemaining: response.freeRegensRemaining ?? 0,
            countedAgainstDailyLimit: response.countedAgainstDailyLimit ?? true
        )
    }

    private func invoke(
        _ ingredientNames: [String],
        options: GenerationOptions,
        count: Int,
        intent: String
    ) async throws -> AIRecipeResponse {
        let cleaned = ingredientNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else { throw RecipeGenerationError.noIngredients }

        let body = RecipeGenerationRequest(
            ingredientNames: cleaned,
            options: .init(options),
            count: count,
            intent: intent
        )

        do {
            return try await client.functions.invoke(
                "generate-recipes",
                options: FunctionInvokeOptions(body: body)
            )
        } catch let FunctionsError.httpError(code, data) {
            if code == 429 { throw RecipeGenerationError.limitExhausted }
            let detail = String(data: data, encoding: .utf8) ?? "status \(code)"
            throw RecipeGenerationError.apiError(detail)
        } catch is DecodingError {
            throw RecipeGenerationError.parsingError
        }
    }
}

// MARK: - Request DTO

/// Flat, primitives-only mirror of `GenerationOptions` for the edge function. `dietType` / `cuisine`
/// are sent as their display raw values ("Any", "Italian", …) — the function's prompt text expects
/// exactly those, matching the app's former `RecipePromptBuilder`.
private struct RecipeGenerationRequest: Encodable {
    let ingredientNames: [String]
    let options: Options
    let count: Int
    let intent: String

    struct Options: Encodable {
        let dietType: String
        let dietaryRestrictions: [String]
        let allergies: [String]
        let maxTimeMinutes: Int
        let targetCalories: Int?
        let cuisine: String?
        let skillLevel: Int
        let priorityIngredients: [String]
        let diversifyIngredients: Bool

        init(_ o: GenerationOptions) {
            dietType = o.dietType.rawValue
            dietaryRestrictions = o.dietaryRestrictions.map(\.rawValue)
            allergies = o.allergies
            maxTimeMinutes = o.maxTimeMinutes
            targetCalories = o.targetCalories
            cuisine = o.cuisine?.rawValue
            skillLevel = o.skillLevel
            priorityIngredients = o.priorityIngredients
            diversifyIngredients = o.diversifyIngredients
        }
    }
}
