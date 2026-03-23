import Foundation

final class MockRecipeGenerator: RecipeGenerating {
    func generateRecipes(for ingredientNames: [String], options: GenerationOptions) async throws -> [Recipe] {
        let cleaned = ingredientNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else {
            throw RecipeGenerationError.noIngredients
        }

        try await Task.sleep(for: .seconds(3))

        let uniqueIngredients = Array(Set(cleaned)).sorted()
        let templates = recipeTemplates(for: uniqueIngredients)

        return templates.map { template in
            let macros = estimateMacros(
                for: template.ingredientsUsed,
                servings: template.servings,
                dietary: options.dietType
            )

            return Recipe(
                title: template.title,
                summary: template.summary,
                timeMinutes: min(template.timeMinutes, options.maxTimeMinutes + 15),
                servings: template.servings,
                ingredientsUsed: template.ingredientsUsed,
                missingIngredients: template.missingIngredients,
                steps: template.steps,
                macros: macros,
                sources: template.sources
            )
        }
    }

    private func recipeTemplates(for ingredients: [String]) -> [RecipeTemplate] {
        let has = { (value: String) in ingredients.contains(value) }
        var templates: [RecipeTemplate] = []

        if has("chicken breast") && has("rice") {
            templates.append(
                RecipeTemplate(
                    title: "One-Pan Chicken Rice Bowl",
                    summary: "Savory chicken and rice with quick aromatics from your leftovers.",
                    timeMinutes: 28,
                    servings: 2,
                    ingredientsUsed: [.init(name: "chicken breast"), .init(name: "rice"), .init(name: "onion"), .init(name: "garlic")],
                    missingIngredients: [.init(name: "soy sauce")],
                    steps: [
                        "Dice chicken and season with salt and pepper.",
                        "Saute onion and garlic until fragrant, then add chicken.",
                        "Stir in cooked rice and a splash of soy sauce.",
                        "Cook until lightly crisp and serve hot."
                    ],
                    sources: sampleSources(topic: "chicken-rice")
                )
            )
        }

        if has("eggs") && has("spinach") {
            templates.append(
                RecipeTemplate(
                    title: "Spinach Egg Skillet",
                    summary: "A high-protein skillet meal ready in minutes.",
                    timeMinutes: 15,
                    servings: 1,
                    ingredientsUsed: [.init(name: "eggs"), .init(name: "spinach"), .init(name: "olive oil")],
                    missingIngredients: [.init(name: "feta cheese")],
                    steps: [
                        "Warm olive oil in a nonstick pan.",
                        "Wilt spinach for 1 to 2 minutes.",
                        "Crack eggs and cook to your preferred doneness.",
                        "Top with optional feta and black pepper."
                    ],
                    sources: sampleSources(topic: "spinach-eggs")
                )
            )
        }

        if templates.isEmpty {
            templates.append(
                RecipeTemplate(
                    title: "Leftover Toss-Up Stir Fry",
                    summary: "A flexible stir fry that uses whatever ingredients are closest to expiring.",
                    timeMinutes: 22,
                    servings: 2,
                    ingredientsUsed: ingredients.prefix(5).map { RecipeIngredient(name: $0) },
                    missingIngredients: [.init(name: "neutral oil"), .init(name: "soy sauce")],
                    steps: [
                        "Chop all vegetables and proteins into bite-size pieces.",
                        "Start with harder vegetables, then add softer ingredients.",
                        "Add sauce and toss over high heat for 3 to 4 minutes.",
                        "Serve over rice, noodles, or toast."
                    ],
                    sources: sampleSources(topic: "leftover-stir-fry")
                )
            )
        }

        templates.append(
            RecipeTemplate(
                title: "Clean-Out-The-Fridge Soup",
                summary: "A broth-based soup designed for mixed leftovers.",
                timeMinutes: 35,
                servings: 3,
                ingredientsUsed: ingredients.prefix(6).map { RecipeIngredient(name: $0) },
                missingIngredients: [.init(name: "stock cube"), .init(name: "lemon")],
                steps: [
                    "Saute aromatics and sturdy vegetables first.",
                    "Add water or stock and simmer until tender.",
                    "Stir in proteins and delicate greens at the end.",
                    "Finish with lemon and adjust seasoning."
                ],
                sources: sampleSources(topic: "leftover-soup")
            )
        )

        return Array(templates.prefix(3))
    }

    private func estimateMacros(
        for ingredients: [RecipeIngredient],
        servings: Int,
        dietary: GenerationOptions.DietType
    ) -> Macros {
        let proteinBoosters = Set(["chicken breast", "eggs", "greek yogurt", "black beans", "tofu"])
        let carbBoosters = Set(["rice", "potatoes", "pasta", "beans", "tomatoes"])
        let fatBoosters = Set(["olive oil", "cheese", "avocado", "peanut butter"])

        let protein = 16 + ingredients.filter { proteinBoosters.contains($0.name) }.count * 9
        let carbs = 22 + ingredients.filter { carbBoosters.contains($0.name) }.count * 8
        let fat = 9 + ingredients.filter { fatBoosters.contains($0.name) }.count * 6
        let dietaryAdjustment = dietary == .vegan ? -3 : 0

        let totalProtein = max(8, protein + dietaryAdjustment)
        let calories = (totalProtein * 4 + carbs * 4 + fat * 9) / max(servings, 1)

        return Macros(
            calories: calories,
            proteinG: max(8, totalProtein / max(servings, 1)),
            carbsG: max(10, carbs / max(servings, 1)),
            fatG: max(5, fat / max(servings, 1))
        )
    }

    private func sampleSources(topic: String) -> [SourceLink] {
        [
            SourceLink(
                title: "Recipe reference A",
                url: URL(string: "https://example.com/recipe/\(topic)-a")!
            ),
            SourceLink(
                title: "Recipe reference B",
                url: URL(string: "https://example.com/recipe/\(topic)-b")!
            )
        ]
    }
}

private struct RecipeTemplate {
    var title: String
    var summary: String
    var timeMinutes: Int
    var servings: Int
    var ingredientsUsed: [RecipeIngredient]
    var missingIngredients: [RecipeIngredient]
    var steps: [String]
    var sources: [SourceLink]
}
