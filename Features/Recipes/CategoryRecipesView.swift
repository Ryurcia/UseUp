import SwiftUI

struct CategoryRecipesView: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore
    let category: RecipesView.RecipeCategory

    @State private var selectedRecipe: Recipe?
    @State private var navigateToRecipe: Recipe?

    private let gridColumns = [
        GridItem(.flexible(), spacing: DS.Spacing.space3),
        GridItem(.flexible(), spacing: DS.Spacing.space3)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: gridColumns, spacing: DS.Spacing.space3) {
                ForEach(category.recipes) { recipe in
                    Button {
                        selectedRecipe = recipe
                    } label: {
                        categoryRecipeCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.bottom, DS.Spacing.space24)
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
        .background(DS.ColorToken.bgPrimary)
        .sheet(item: $selectedRecipe) { recipe in
            categoryPreviewSheet(recipe: recipe)
        }
        .navigationDestination(item: $navigateToRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
    }

    // MARK: - Recipe Card

    private func categoryRecipeCard(recipe: Recipe) -> some View {
        VStack(spacing: 0) {
            Color.clear
                .aspectRatio(4/3, contentMode: .fit)
                .overlay {
                    CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: true)
                }
                .clipped()
                .overlay(alignment: .bottomLeading) {
                    Text("\(recipe.timeMinutes) min")
                        .font(.custom("Satoshi Variable", size: 11).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DS.ColorToken.accent.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                Text(recipe.title)
                    .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(recipe.summary.isEmpty ? " " : recipe.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(DS.Spacing.space2)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 72)
        }
        .background(DS.ColorToken.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .drawingGroup()
    }

    // MARK: - Preview Sheet

    private func categoryPreviewSheet(recipe: Recipe) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                Capsule()
                    .fill(DS.ColorToken.borderDefault)
                    .frame(width: 36, height: 5)
                    .padding(.top, DS.Spacing.space3)
                    .padding(.bottom, DS.Spacing.space4)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.space6) {
                        CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: true)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))

                        Text(recipe.title)
                            .appTextStyle(.heading2)
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        Text(recipe.summary)
                            .appTextStyle(.body)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        let pantryNames = Set(pantryStore.ingredients.map { $0.name.lowercased() })
                        let matchCount = recipe.ingredientsUsed.filter { pantryNames.contains($0.name.lowercased()) }.count
                        if matchCount > 0 {
                            HStack(spacing: DS.Spacing.space1) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(DS.ColorToken.success)
                                Text("You have \(matchCount) of \(recipe.ingredientsUsed.count) ingredients")
                                    .appTextStyle(.bodySM)
                                    .foregroundStyle(DS.ColorToken.success)
                            }
                        }

                        Button {
                            selectedRecipe = nil
                            navigateToRecipe = recipe
                        } label: {
                            Text("View Full Recipe")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                    }
                    .padding(DS.Spacing.space5)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}
