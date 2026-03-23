import Foundation

final class SonnetRecipeGenerator: RecipeGenerating {

    func generateRecipes(for ingredientNames: [String], options: GenerationOptions) async throws -> [Recipe] {
        let cleaned = ingredientNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else {
            throw RecipeGenerationError.noIngredients
        }

        let systemPrompt = RecipePromptBuilder.buildSystemPrompt()
        let userPrompt = RecipePromptBuilder.buildUserPrompt(ingredientNames: cleaned, options: options)

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                [
                    "role": "user",
                    "content": userPrompt
                ]
            ]
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw RecipeGenerationError.apiError("Invalid Anthropic URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AIConfig.anthropicAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RecipeGenerationError.apiError("Anthropic API error \(httpResponse.statusCode): \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw RecipeGenerationError.emptyResponse
        }

        // Strip markdown fences if present
        let jsonText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let textData = jsonText.data(using: .utf8) else {
            throw RecipeGenerationError.parsingError
        }

        let aiResponse: AIRecipeResponse
        do {
            aiResponse = try JSONDecoder().decode(AIRecipeResponse.self, from: textData)
        } catch {
            throw RecipeGenerationError.parsingError
        }

        let recipes = aiResponse.recipes.map { $0.toRecipe() }

        guard !recipes.isEmpty else {
            throw RecipeGenerationError.emptyResponse
        }

        return recipes
    }
}
