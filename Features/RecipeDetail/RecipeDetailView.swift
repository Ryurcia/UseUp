import SwiftUI

#Preview("Recipe Detail") {
    PreviewContainer {
        NavigationStack {
            RecipeDetailView(recipe: DummyData.sampleSavedRecipes[0])
        }
    }
}

struct RecipeDetailView: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var showRatingSheet = false

    private var pantryMatchedIngredients: [RecipeIngredient] {
        let pantryNames = Set(pantryStore.ingredients.map { $0.name.lowercased() })
        return recipe.ingredientsUsed.filter { pantryNames.contains($0.name.lowercased()) }
    }

    private func sufficiency(for ingredient: RecipeIngredient) -> IngredientSufficiency {
        guard let pantryItem = pantryStore.ingredients.first(where: {
            $0.name.lowercased() == ingredient.name.lowercased()
        }) else { return .notInPantry }
        return IngredientComparator.compare(
            recipeQuantity: ingredient.quantity,
            pantryAmount: pantryItem.amount
        )
    }

    private var currentRecipe: Recipe {
        savedRecipesStore.sharedRecipes.first(where: { $0.id == recipe.id })
            ?? savedRecipesStore.savedRecipes.first(where: { $0.id == recipe.id })
            ?? recipe
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.space5) {
                ZStack(alignment: .bottom) {
                    recipeImage
                        .overlay(alignment: .top) {
                            headerOverlay
                                .padding(.top, DS.Spacing.space2)
                        }

                    summaryCard
                        .padding(.horizontal, DS.Spacing.space5)
                        .offset(y: 80)
                }
                .padding(.bottom, 80)

                VStack(spacing: DS.Spacing.space5) {
                    ingredientsCard
                    if !pantryMatchedIngredients.isEmpty {
                        pantryMatchCard
                    }
                    if !recipe.missingIngredients.isEmpty {
                        missingIngredientsCard
                    }
                    stepsCard
                    if !recipe.sources.isEmpty {
                        sourcesCard
                    }
                }
                .padding(.horizontal, DS.Spacing.space5)
            }
            .padding(.bottom, DS.Spacing.space24)
        }
        .background(DS.ColorToken.bgPrimary)
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .background(SwipeBackEnabler())
        .sheet(isPresented: $showRatingSheet) {
            RateRecipeSheet(recipe: recipe, currentRating: Int(currentRecipe.rating), currentReview: currentRecipe.review ?? "") { rating, review in
                savedRecipesStore.rateRecipe(recipe, rating: rating, review: review)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Header Overlay

    private var headerOverlay: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                savedRecipesStore.toggleSaved(recipe)
            } label: {
                Image(systemName: savedRecipesStore.isSaved(recipe) ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.top, DS.Spacing.space10)
    }

    // MARK: - Image

    private var recipeImage: some View {
        GeometryReader { proxy in
            let safeTop = proxy.safeAreaInsets.top
            Group {
                if recipe.isAIGenerated && recipe.imageData == nil && recipe.imagePath == nil {
                    LinearGradient(
                        colors: [DS.ColorToken.primary, DS.ColorToken.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath)
                }
            }
            .frame(height: 300 + safeTop)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .topLeading) {
                if recipe.isAIGenerated {
                    AIGeneratedBadge()
                        .padding(.horizontal, DS.Spacing.space5)
                        .padding(.top, safeTop + DS.Spacing.space16)
                }
            }
            .offset(y: -safeTop)
        }
        .frame(height: 300)
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space3) {
            Text(recipe.title)
                .appTextStyle(.heading2)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Text(recipe.summary)
                .appTextStyle(.bodySM)
                .foregroundStyle(DS.ColorToken.textSecondary)

            HStack(spacing: DS.Spacing.space4) {
                Label("\(recipe.timeMinutes) min", systemImage: "clock")
                Label("\(recipe.servings) servings", systemImage: "person.2")
            }
            .appTextStyle(.bodySM)
            .foregroundStyle(DS.ColorToken.textTertiary)

            if let displayName = recipe.createdByName ?? recipe.createdBy {
                HStack(spacing: DS.Spacing.space1) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 12))
                    Text("Created by \(displayName)")
                }
                .appTextStyle(.caption)
                .foregroundStyle(DS.ColorToken.textTertiary)
            }

            HStack(spacing: DS.Spacing.space2) {
                StarRatingView(rating: currentRecipe.rating, size: 20)

                Button {
                    showRatingSheet = true
                } label: {
                    Text(currentRecipe.rating > 0 ? "Edit Rating" : "Rate It")
                        .font(.custom("Satoshi Variable", size: 13).weight(.semibold))
                        .foregroundStyle(DS.ColorToken.primary)
                }
                .buttonStyle(.plain)
            }

            if let review = currentRecipe.review, !review.isEmpty {
                Text("\"\(review)\"")
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .italic()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardStyle())
    }

    // MARK: - Ingredients

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space3) {
            sectionLabel("Ingredients Used", icon: "basket.fill")

            VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                ForEach(recipe.ingredientsUsed) { ingredient in
                    let state = sufficiency(for: ingredient)
                    ingredientRow(ingredient: ingredient, state: state)
                }
            }
        }
        .modifier(CardStyle())
    }

    // MARK: - Pantry Match

    private var pantryMatchCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space3) {
            sectionLabel("Already In Your Pantry", icon: "checkmark.seal.fill")

            VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                ForEach(pantryMatchedIngredients) { ingredient in
                    let state = sufficiency(for: ingredient)
                    ingredientRow(ingredient: ingredient, state: state)
                }
            }
        }
        .modifier(CardStyle())
    }

    // MARK: - Missing Ingredients

    private var missingIngredientsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space3) {
            sectionLabel("You May Still Need", icon: "cart.fill")

            VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                ForEach(recipe.missingIngredients) { ingredient in
                    HStack(spacing: DS.Spacing.space2) {
                        Circle()
                            .fill(DS.ColorToken.warning)
                            .frame(width: 6, height: 6)
                        Text(ingredient.displayText)
                            .appTextStyle(.bodySM)
                            .foregroundStyle(DS.ColorToken.textPrimary)
                    }
                }
            }
        }
        .modifier(CardStyle())
    }

    // MARK: - Steps

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space3) {
            sectionLabel("Steps", icon: "list.number")

            VStack(alignment: .leading, spacing: DS.Spacing.space4) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: DS.Spacing.space3) {
                        Text("\(index + 1)")
                            .font(.custom("Satoshi Variable", size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(DS.ColorToken.primary)
                            .clipShape(Circle())

                        Text(step)
                            .appTextStyle(.bodySM)
                            .foregroundStyle(DS.ColorToken.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .modifier(CardStyle())
    }

    // MARK: - Sources

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space3) {
            sectionLabel("Sources", icon: "link")

            VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                ForEach(recipe.sources) { source in
                    Link(destination: source.url) {
                        HStack(spacing: DS.Spacing.space2) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.ColorToken.primary)
                            Text(source.title)
                                .appTextStyle(.bodySM)
                                .foregroundStyle(DS.ColorToken.primary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .modifier(CardStyle())
    }

    // MARK: - Helpers

    @ViewBuilder
    private func ingredientRow(ingredient: RecipeIngredient, state: IngredientSufficiency) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: DS.Spacing.space2) {
                switch state {
                case .enough, .unknownAmount:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.ColorToken.success)
                case .partial:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.ColorToken.warning)
                case .notInPantry:
                    Circle()
                        .fill(DS.ColorToken.primary)
                        .frame(width: 6, height: 6)
                }
                Text(ingredient.displayText)
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.textPrimary)
            }
            if case let .partial(have, need) = state {
                Text("You have \(have) — recipe needs \(need)")
                    .appTextStyle(.caption)
                    .foregroundStyle(DS.ColorToken.textTertiary)
                    .padding(.leading, DS.Spacing.space4)
            }
        }
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: DS.Spacing.space2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(DS.ColorToken.primary)
            Text(title)
                .appTextStyle(.overline)
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
    }
}

// MARK: - Card Style

// MARK: - Rate Recipe Sheet

private struct RateRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var selectedRating: Int
    @State private var reviewText: String
    let onSubmit: (Int, String?) -> Void

    init(recipe: Recipe, currentRating: Int, currentReview: String, onSubmit: @escaping (Int, String?) -> Void) {
        self.recipe = recipe
        self._selectedRating = State(initialValue: currentRating)
        self._reviewText = State(initialValue: currentReview)
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DS.ColorToken.borderDefault)
                .frame(width: 36, height: 5)
                .padding(.top, DS.Spacing.space3)
                .padding(.bottom, DS.Spacing.space4)

            VStack(spacing: DS.Spacing.space5) {
                // Header
                HStack {
                    Text("Rate This Recipe")
                        .appTextStyle(.heading2)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .buttonStyle(.plain)
                }

                // Star picker
                VStack(spacing: DS.Spacing.space2) {
                    Text("Tap a star to rate")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textTertiary)

                    StarRatingView(rating: Double(selectedRating), size: 36, interactive: true) { newRating in
                        selectedRating = newRating
                    }
                }

                // Comment input
                VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                    Text("Leave a comment (optional)")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)

                    TextField("What did you think?", text: $reviewText, axis: .vertical)
                        .lineLimit(3...6)
                        .appTextStyle(.body)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .padding(DS.Spacing.space3)
                        .background(DS.ColorToken.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                }
            }
            .padding(.horizontal, DS.Spacing.space5)

            Spacer()

            Button {
                onSubmit(selectedRating, reviewText.isEmpty ? nil : reviewText)
                dismiss()
            } label: {
                Text("Submit")
                    .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(selectedRating > 0 ? DS.ColorToken.primary : DS.ColorToken.primary.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedRating == 0)
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space4)
        }
        .background(DS.ColorToken.bgPrimary)
    }
}

// MARK: - Card Style

private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DS.Spacing.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.ColorToken.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.ColorToken.borderDefault, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
