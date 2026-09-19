import Foundation

final class MockRecipeGenerator: RecipeGenerating {
    func generateRecipes(for ingredientNames: [String], options: GenerationOptions, count: Int) async throws -> [Recipe] {
        let cleaned = ingredientNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else {
            throw RecipeGenerationError.noIngredients
        }

        try await Task.sleep(for: .seconds(3))

        let uniqueIngredients = Array(Set(cleaned)).sorted()
        let templates = Array(recipeTemplates(for: uniqueIngredients).prefix(count))

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
                sources: template.sources,
                dietType: template.dietType,
                dietaryRestrictions: template.dietaryRestrictions,
                isAIGenerated: true
            )
        }
    }

    func snapChefRecipe(for ingredientNames: [String], options: GenerationOptions) async throws -> SnapChefGeneration {
        let recipes = try await generateRecipes(for: ingredientNames, options: options, count: 1)
        guard let recipe = recipes.first else { throw RecipeGenerationError.emptyResponse }
        return SnapChefGeneration(recipe: recipe)
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

        templates.append(
            RecipeTemplate(
                title: "Garlic Butter Pasta",
                summary: "A quick weeknight pasta that comes together in under 20 minutes with pantry staples.",
                timeMinutes: 18,
                servings: 2,
                ingredientsUsed: [.init(name: "pasta"), .init(name: "garlic"), .init(name: "butter"), .init(name: "parmesan")],
                missingIngredients: [.init(name: "fresh parsley")],
                steps: [
                    "Boil salted water and cook pasta until al dente, reserving half a cup of pasta water.",
                    "Melt butter in a pan over medium heat and saute sliced garlic for 2 minutes.",
                    "Toss drained pasta into the pan with a splash of pasta water.",
                    "Remove from heat, stir in parmesan, and season to taste."
                ],
                sources: sampleSources(topic: "garlic-butter-pasta")
            )
        )

        templates.append(
            RecipeTemplate(
                title: "Sheet Pan Roasted Vegetables",
                summary: "Caramelised mixed vegetables with olive oil and herbs — minimal effort, maximum flavour.",
                timeMinutes: 40,
                servings: 3,
                ingredientsUsed: ingredients.prefix(5).map { RecipeIngredient(name: $0) },
                missingIngredients: [.init(name: "olive oil"), .init(name: "dried thyme")],
                steps: [
                    "Preheat oven to 220°C (425°F) and line a baking sheet with parchment.",
                    "Cut all vegetables into similar-sized pieces and spread in a single layer.",
                    "Drizzle with olive oil, season generously, and scatter over thyme.",
                    "Roast for 25 to 30 minutes, flipping halfway, until golden at the edges."
                ],
                sources: sampleSources(topic: "sheet-pan-veg"),
                dietType: "Vegan",
                dietaryRestrictions: ["Gluten-Free"]
            )
        )

        templates.append(
            RecipeTemplate(
                title: "Greek Yogurt Parfait",
                summary: "A protein-packed no-cook breakfast layered with fruit and a honey drizzle.",
                timeMinutes: 5,
                servings: 1,
                ingredientsUsed: [.init(name: "greek yogurt"), .init(name: "berries"), .init(name: "honey"), .init(name: "granola")],
                missingIngredients: [],
                steps: [
                    "Spoon half the yogurt into a glass or bowl.",
                    "Add a layer of berries and a handful of granola.",
                    "Repeat with remaining yogurt and toppings.",
                    "Finish with a drizzle of honey and serve immediately."
                ],
                sources: sampleSources(topic: "yogurt-parfait"),
                dietType: "Vegetarian"
            )
        )

        return templates
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
    var dietType: String = "any"
    var dietaryRestrictions: [String] = []
}
