import SwiftUI

struct CategoryRecipesView: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore
    let category: RecipesView.RecipeCategory

    @State private var selectedRecipe: Recipe?
    @State private var navigateToRecipe: Recipe?
    @State private var recipeToReport: Recipe?
    @State private var ratingsRecipe: Recipe?

    private let gridColumns = [
        GridItem(.flexible(), spacing: DS.Spacing.space4),
        GridItem(.flexible(), spacing: DS.Spacing.space4)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.space5) {
                ForEach(category.recipes) { recipe in
                    let actions = RecipeCardActions(
                        recipe: recipe,
                        savedRecipesStore: savedRecipesStore,
                        reportRecipe: { recipeToReport = $0 },
                        rateRecipe: { ratingsRecipe = $0 }
                    )
                    Button {
                        selectedRecipe = recipe
                    } label: {
                        RecipeCard(
                            recipe: recipe,
                            showBadge: false,
                            isSaved: savedRecipesStore.isSaved(recipe),
                            onReport: actions.onReport,
                            onRate: actions.onRate,
                            onSave: actions.onSave
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space24)
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
        .background(DS.ColorToken.bgPrimary)
        .sheet(item: $selectedRecipe) { recipe in
            RecipePreviewSheet(recipe: recipe) {
                selectedRecipe = nil
                navigateToRecipe = recipe
            }
        }
        .sheet(item: $recipeToReport) { recipe in
            ReportContentSheet(subject: .recipe(name: recipe.title)) { category, description in
                Task { try? await savedRecipesStore.reportRecipe(recipe, category: category, description: description) }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(item: $navigateToRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .navigationDestination(item: $ratingsRecipe) { recipe in
            RecipeRatingsView(recipe: recipe)
        }
    }
}
