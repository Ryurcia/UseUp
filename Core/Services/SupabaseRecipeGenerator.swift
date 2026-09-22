import Foundation
import Supabase

/// Calls the `generate-recipes` Supabase edge function, which holds the Gemini API key, enforces
/// the generation quota, and serves the system prompt from a shared Gemini cache. The app only
/// sends structured ingredients + options; the function builds the prompt and calls Gemini.
final class SupabaseRecipeGenerator: RecipeGenerating {
    private let client = SupabaseManager.client

    func generateRecipes(for ingredientNames: [String], options: GenerationOptions, count: Int) async throws -> [Recipe] {
        let response = try await invoke(ingredientNames, options: options, count: count)
        let recipes = response.recipes.prefix(count).map {
            $0.toRecipe(
                dietType: options.dietType.rawValue.lowercased(),
                dietaryRestrictions: options.dietaryRestrictions.map(\.rawValue)
            )
        }
        guard !recipes.isEmpty else { throw RecipeGenerationError.emptyResponse }
        return recipes
    }

    private func invoke(
        _ ingredientNames: [String],
        options: GenerationOptions,
        count: Int
    ) async throws -> AIRecipeResponse {
        let cleaned = ingredientNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else { throw RecipeGenerationError.noIngredients }

        let body = RecipeGenerationRequest(
            ingredientNames: cleaned,
            options: .init(options),
            count: count
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

    struct Options: Encodable {
        let dietType: String
        let dietaryRestrictions: [String]
        let allergies: [String]
        let maxTimeMinutes: Int
        let targetCalories: Int?
        let cuisine: String?
        let skillLevel: Int
        let priorityIngredients: [String]

        init(_ o: GenerationOptions) {
            dietType = o.dietType.rawValue
            dietaryRestrictions = o.dietaryRestrictions.map(\.rawValue)
            allergies = o.allergies
            maxTimeMinutes = o.maxTimeMinutes
            targetCalories = o.targetCalories
            cuisine = o.cuisine?.rawValue
            skillLevel = o.skillLevel
            priorityIngredients = o.priorityIngredients
        }
    }
}
