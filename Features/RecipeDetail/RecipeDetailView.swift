import SwiftUI
import RevenueCatUI

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
    @EnvironmentObject private var activityStore: UserActivityStore
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var showRatingSheet = false
    @State private var showSavePaywall = false
    @State private var showCategoryPicker = false
    @State private var showPDFShare = false
    @State private var pdfURL: URL?


    private var currentRecipe: Recipe {
        savedRecipesStore.sharedRecipes.first(where: { $0.id == recipe.id })
            ?? savedRecipesStore.savedRecipes.first(where: { $0.id == recipe.id })
            ?? savedRecipesStore.communityRecipes.first(where: { $0.id == recipe.id })
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
                        .offset(y: 120)
                }
                .padding(.bottom, 120)

                VStack(spacing: DS.Spacing.space5) {
                    VStack(spacing: DS.Spacing.space2) {
                        saveToCookbookButton
                        saveAsPDFButton
                    }

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
                    communityReviewsCard
                }
                .padding(.horizontal, DS.Spacing.space5)
            }
            .padding(.bottom, DS.Spacing.space24)
        }
        .background(DS.ColorToken.bgPrimary)
        .ignoresSafeArea(edges: [.top, .bottom])
        .navigationBarHidden(true)
        .preference(key: HideTabBarKey.self, value: true)
        .background(SwipeBackEnabler())
        .task {
            await savedRecipesStore.fetchCommunityReviews(for: recipe.id)
        }
        .sheet(isPresented: $showRatingSheet) {
            RateRecipeSheet(recipe: recipe, currentRating: Int(currentRecipe.userRating ?? 0), currentReview: currentRecipe.review ?? "") { rating, review in
                savedRecipesStore.rateRecipe(recipe, rating: rating, review: review)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCategoryPicker) {
            SaveCategoryPicker { category in
                savedRecipesStore.saveRecipe(recipe, category: category)
                showCategoryPicker = false
            }
            .presentationDetents([.height(360)])
        }
        .sheet(isPresented: $showSavePaywall) {
            PaywallView()
                .onPurchaseCompleted { _ in showSavePaywall = false }
                .onRestoreCompleted { _ in showSavePaywall = false }
        }
        .sheet(isPresented: $showPDFShare) {
            if let pdfURL {
                ShareSheet(items: [pdfURL])
            }
        }
    }

    // MARK: - Save to Cookbook

    private var saveToCookbookButton: some View {
        let isSaved = savedRecipesStore.isSaved(recipe)

        return Button {
            if session.isPremium {
                if isSaved {
                    savedRecipesStore.unsaveRecipe(recipe)
                } else {
                    showCategoryPicker = true
                }
            } else {
                showSavePaywall = true
            }
        } label: {
            HStack(spacing: DS.Spacing.space2) {
                if !session.isPremium {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                } else {
                    Image(systemName: isSaved ? "checkmark" : "bookmark")
                        .font(.system(size: 14, weight: .semibold))
                }

                Text(isSaved && session.isPremium ? "Saved to Cookbook" : "Save to Cookbook")
                    .font(.custom("Satoshi Variable", size: 15).weight(.semibold))

                if !session.isPremium {
                    Text("PRO")
                        .font(.custom("Satoshi Variable", size: 9).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            LinearGradient(
                                colors: [DS.ColorToken.berry, DS.ColorToken.lavender],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(isSaved && session.isPremium ? DS.ColorToken.accent : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                isSaved && session.isPremium
                    ? DS.ColorToken.accentLight
                    : DS.ColorToken.accent
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                    .stroke(isSaved && session.isPremium ? DS.ColorToken.accent.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Save as PDF

    private var saveAsPDFButton: some View {
        Button {
            if session.isPremium {
                pdfURL = generatePDF()
                if pdfURL != nil { showPDFShare = true }
            } else {
                showSavePaywall = true
            }
        } label: {
            HStack(spacing: DS.Spacing.space2) {
                if !session.isPremium {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                } else {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 14, weight: .semibold))
                }

                Text("Save as PDF")
                    .font(.custom("Satoshi Variable", size: 15).weight(.semibold))

                if !session.isPremium {
                    Text("PRO")
                        .font(.custom("Satoshi Variable", size: 9).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            LinearGradient(
                                colors: [DS.ColorToken.berry, DS.ColorToken.lavender],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                        .clipShape(Capsule())
                }
            }
            .foregroundStyle(DS.ColorToken.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(DS.ColorToken.primaryLight)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                    .stroke(DS.ColorToken.primary.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func generatePDF() -> URL? {
        let printView = RecipePrintView(recipe: recipe)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: printView)
        renderer.proposedSize = .init(width: 612, height: nil)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(recipe.title).pdf")

        renderer.render { size, renderInContext in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            renderInContext(context)
            context.endPDFPage()
            context.closePDF()
        }

        return FileManager.default.fileExists(atPath: url.path) ? url : nil
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
                    ZStack {
                        LinearGradient(
                            colors: [DS.ColorToken.primary, DS.ColorToken.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "fork.knife")
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
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

            if !recipe.dietaryRestrictions.isEmpty || recipe.dietType != "any" {
                FlowLayout(spacing: DS.Spacing.space1) {
                    if recipe.dietType != "any" {
                        Text(recipe.dietType.capitalized)
                            .font(.custom("Satoshi Variable", size: 11).weight(.semibold))
                            .foregroundStyle(DS.ColorToken.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DS.ColorToken.accentLight)
                            .clipShape(Capsule())
                    }
                    ForEach(recipe.dietaryRestrictions, id: \.self) { restriction in
                        Text(restriction)
                            .font(.custom("Satoshi Variable", size: 11).weight(.semibold))
                            .foregroundStyle(DS.ColorToken.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DS.ColorToken.primaryLight)
                            .clipShape(Capsule())
                    }
                }
            }

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
                    Text(currentRecipe.userRating != nil ? "Edit Rating" : "Rate It")
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
            sectionLabel("Ingredients", icon: "basket.fill")

            VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                ForEach(recipe.ingredientsUsed) { ingredient in
                    HStack(spacing: DS.Spacing.space2) {
                        Circle()
                            .fill(DS.ColorToken.primary)
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

    // MARK: - Pantry Match

    private var pantryMatchedIngredients: [RecipeIngredient] {
        let pantryNames = Set(pantryStore.ingredients.map { $0.name.lowercased() })
        return recipe.ingredientsUsed.filter { pantryNames.contains($0.name.lowercased()) }
    }

    private var pantryMatchCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space3) {
            sectionLabel("Ingredients you may already have", icon: "checkmark.seal.fill")

            VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                ForEach(pantryMatchedIngredients) { ingredient in
                    HStack(spacing: DS.Spacing.space2) {
                        Circle()
                            .fill(DS.ColorToken.accent)
                            .frame(width: 6, height: 6)
                        Text(ingredient.name.capitalized)
                            .appTextStyle(.bodySM)
                            .foregroundStyle(DS.ColorToken.textPrimary)
                    }
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

    // MARK: - Community Reviews

    @ViewBuilder
    private var communityReviewsCard: some View {
        let reviews = savedRecipesStore.communityReviews[recipe.id] ?? []
        if !reviews.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                sectionLabel("Community Reviews", icon: "bubble.left.and.text.bubble.right.fill")

                ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
                    ReviewRowView(review: review)
                    if index < reviews.count - 1 {
                        Divider()
                    }
                }
            }
            .modifier(CardStyle())
        }
    }

    // MARK: - Helpers

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

// MARK: - Review Row

private struct ReviewRowView: View {
    let review: CommunityReview
    @State private var avatarImage: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.space3) {
            if let image = avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(DS.ColorToken.accent)
                    .frame(width: 32, height: 32)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                HStack {
                    Text(review.nickname)
                        .appTextStyle(.bodySM)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                    Spacer()
                    StarRatingView(rating: review.rating, size: 12)
                }

                if let reviewText = review.review, !reviewText.isEmpty {
                    Text(reviewText)
                        .appTextStyle(.bodySM)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .lineLimit(4)
                }
            }
        }
        .task {
            await loadAvatar()
        }
    }

    private func loadAvatar() async {
        guard let avatarPath = review.avatarPath, !avatarPath.isEmpty else { return }
        if let cached = AvatarCache.load(for: avatarPath),
           let image = UIImage(data: cached) {
            avatarImage = image
            return
        }
        do {
            let data = try await SupabaseManager.client.storage
                .from("profile-photos")
                .download(path: avatarPath)
            AvatarCache.save(data, for: avatarPath)
            avatarImage = UIImage(data: data)
        } catch {
            // Fallback stays as person.circle.fill
        }
    }
}

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

// MARK: - Recipe Print View

private struct RecipePrintView: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space5) {
            // Title
            Text(recipe.title)
                .font(.custom("CalSans-Regular", size: 28))
                .foregroundStyle(DS.ColorToken.textPrimary)

            // Summary
            Text(recipe.summary)
                .appTextStyle(.bodySM)
                .foregroundStyle(DS.ColorToken.textSecondary)

            // Meta
            HStack(spacing: DS.Spacing.space4) {
                Label("\(recipe.timeMinutes) min", systemImage: "clock")
                Label("\(recipe.servings) servings", systemImage: "person.2")
                Label(recipe.cuisine.rawValue, systemImage: "fork.knife")
            }
            .appTextStyle(.caption)
            .foregroundStyle(DS.ColorToken.textTertiary)

            // Ingredients card
            VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                HStack(spacing: DS.Spacing.space2) {
                    Image(systemName: "basket.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.ColorToken.primary)
                    Text("Ingredients")
                        .appTextStyle(.overline)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }

                ForEach(recipe.ingredientsUsed) { ingredient in
                    HStack(spacing: DS.Spacing.space2) {
                        Circle()
                            .fill(DS.ColorToken.primary)
                            .frame(width: 6, height: 6)
                        Text(ingredient.displayText)
                            .appTextStyle(.bodySM)
                            .foregroundStyle(DS.ColorToken.textPrimary)
                    }
                }
            }
            .padding(DS.Spacing.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.ColorToken.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))

            if !recipe.missingIngredients.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                    HStack(spacing: DS.Spacing.space2) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(DS.ColorToken.warning)
                        Text("Missing Ingredients")
                            .appTextStyle(.overline)
                            .foregroundStyle(DS.ColorToken.textSecondary)
                    }

                    ForEach(recipe.missingIngredients) { ingredient in
                        HStack(spacing: DS.Spacing.space2) {
                            Circle()
                                .fill(DS.ColorToken.warning)
                                .frame(width: 6, height: 6)
                            Text(ingredient.displayText)
                                .appTextStyle(.bodySM)
                                .foregroundStyle(DS.ColorToken.textSecondary)
                        }
                    }
                }
                .padding(DS.Spacing.space4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DS.ColorToken.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            }

            // Steps card
            VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                HStack(spacing: DS.Spacing.space2) {
                    Image(systemName: "list.number")
                        .font(.system(size: 14))
                        .foregroundStyle(DS.ColorToken.primary)
                    Text("Steps")
                        .appTextStyle(.overline)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }

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
            .padding(DS.Spacing.space4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.ColorToken.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))

            // Macros
            HStack(spacing: DS.Spacing.space4) {
                macroItem(label: "Calories", value: "\(recipe.macros.calories)", color: DS.ColorToken.primary)
                macroItem(label: "Protein", value: "\(recipe.macros.proteinG)g", color: DS.ColorToken.accent)
                macroItem(label: "Carbs", value: "\(recipe.macros.carbsG)g", color: DS.ColorToken.warning)
                macroItem(label: "Fat", value: "\(recipe.macros.fatG)g", color: DS.ColorToken.error)
            }
            .padding(DS.Spacing.space4)
            .frame(maxWidth: .infinity)
            .background(DS.ColorToken.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        }
        .padding(40)
        .background(DS.ColorToken.bgPrimary)
    }

    private func macroItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Satoshi Variable", size: 16).weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .appTextStyle(.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Save Category Picker

private struct SaveCategoryPicker: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String?) -> Void

    private let categories: [(label: String, value: String?, icon: String)] = [
        ("Breakfast", "breakfast", "sunrise.fill"),
        ("Lunch", "lunch", "sun.max.fill"),
        ("Dinner", "dinner", "moon.fill"),
        ("Snack", "snack", "cup.and.saucer.fill"),
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.space4) {
            Capsule()
                .fill(DS.ColorToken.borderDefault)
                .frame(width: 36, height: 5)
                .padding(.top, DS.Spacing.space3)

            Text("Save to Cookbook")
                .font(.custom("CalSans-Regular", size: 20))
                .foregroundStyle(DS.ColorToken.textPrimary)

            Text("Choose a category")
                .appTextStyle(.bodySM)
                .foregroundStyle(DS.ColorToken.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.space3), GridItem(.flexible(), spacing: DS.Spacing.space3)], spacing: DS.Spacing.space3) {
                ForEach(categories, id: \.label) { cat in
                    Button {
                        onSelect(cat.value)
                    } label: {
                        VStack(spacing: DS.Spacing.space2) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 24))
                                .foregroundStyle(DS.ColorToken.primary)

                            Text(cat.label)
                                .font(.custom("Satoshi Variable", size: 14).weight(.semibold))
                                .foregroundStyle(DS.ColorToken.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(DS.ColorToken.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.space5)

            Button {
                onSelect(nil)
            } label: {
                Text("Just Save")
                    .font(.custom("Satoshi Variable", size: 15).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(DS.ColorToken.primary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.space5)

            Spacer()
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

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
