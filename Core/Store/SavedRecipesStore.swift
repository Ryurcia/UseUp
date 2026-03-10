import Foundation

@MainActor
final class SavedRecipesStore: ObservableObject {
    @Published private(set) var savedRecipes: [Recipe]
    @Published private(set) var sharedRecipes: [Recipe]

    init(
        savedRecipes: [Recipe] = DummyData.sampleSavedRecipes,
        sharedRecipes: [Recipe] = DummyData.sampleSharedRecipes
    ) {
        self.savedRecipes = savedRecipes
        self.sharedRecipes = sharedRecipes
    }

    func isSaved(_ recipe: Recipe) -> Bool {
        savedRecipes.contains(where: { $0.id == recipe.id })
    }

    func toggleSaved(_ recipe: Recipe) {
        if let index = savedRecipes.firstIndex(where: { $0.id == recipe.id }) {
            savedRecipes.remove(at: index)
        } else {
            savedRecipes.insert(recipe, at: 0)
        }
    }

    func addSharedRecipe(
        title: String,
        summary: String,
        timeMinutes: Int,
        servings: Int,
        ingredients: [RecipeIngredient],
        steps: [String],
        macros: Macros,
        sources: [SourceLink],
        imageData: Data? = nil,
        cuisine: Cuisine
    ) {
        let recipe = Recipe(
            title: title,
            summary: summary,
            timeMinutes: timeMinutes,
            servings: servings,
            ingredientsUsed: ingredients,
            missingIngredients: [],
            steps: steps,
            macros: macros,
            sources: sources,
            isUserShared: true,
            imageData: imageData,
            cuisine: cuisine
        )
        sharedRecipes.insert(recipe, at: 0)
    }

    func rateRecipe(_ recipe: Recipe, rating: Int, review: String? = nil) {
        let clamped = Double(min(max(rating, 1), 5))
        let trimmedReview = review?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalReview = (trimmedReview?.isEmpty ?? true) ? nil : trimmedReview
        if let index = sharedRecipes.firstIndex(where: { $0.id == recipe.id }) {
            sharedRecipes[index].rating = clamped
            sharedRecipes[index].review = finalReview
        }
        if let index = savedRecipes.firstIndex(where: { $0.id == recipe.id }) {
            savedRecipes[index].rating = clamped
            savedRecipes[index].review = finalReview
        }
    }
}
