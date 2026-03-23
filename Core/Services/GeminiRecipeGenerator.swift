import Foundation

final class GeminiRecipeGenerator: RecipeGenerating {

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
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": userPrompt]]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.7,
                "thinkingConfig": [
                    "thinkingBudget": 0
                ]
            ]
        ]

        let apiKey = AIConfig.geminiAPIKey
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)") else {
            throw RecipeGenerationError.apiError("Invalid Gemini URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RecipeGenerationError.apiError("Gemini API error \(httpResponse.statusCode): \(body)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw RecipeGenerationError.emptyResponse
        }

        // Gemini 2.5 "thinking" models return a thought part followed by the text part.
        // Find the last part that has a "text" key and is NOT a thought.
        guard let text = parts.last(where: { $0["thought"] == nil })?["text"] as? String else {
            throw RecipeGenerationError.emptyResponse
        }

        guard let textData = text.data(using: .utf8) else {
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
