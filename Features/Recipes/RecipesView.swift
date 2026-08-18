import SwiftUI
import PhosphorSwift

#Preview("Recipes") {
    PreviewContainer {
        NavigationStack {
            RecipesView()
        }
    }
}

// Tabs removed — community only

// MARK: - Image Cache

final class RecipeImageCache {
    static let shared = RecipeImageCache()

    private let fullCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        return cache
    }()

    private let thumbCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 150
        cache.totalCostLimit = 20 * 1024 * 1024 // 20 MB
        return cache
    }()

    func image(for id: UUID, thumbnail: Bool = false) -> UIImage? {
        let key = id.uuidString as NSString
        return thumbnail ? thumbCache.object(forKey: key) : fullCache.object(forKey: key)
    }

    func clear() {
        fullCache.removeAllObjects()
        thumbCache.removeAllObjects()
    }

    func setImage(_ image: UIImage, for id: UUID, thumbnail: Bool = false, cost: Int = 0) {
        let key = id.uuidString as NSString
        if thumbnail {
            thumbCache.setObject(image, forKey: key, cost: cost)
        } else {
            fullCache.setObject(image, forKey: key, cost: cost)
        }
    }

    static func generateThumbnail(from data: Data, maxPixelSize: Int = 800) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Cached Recipe Image

struct CachedRecipeImage: View {
    let recipeID: UUID
    let imageData: Data?
    let imagePath: String?
    let thumbnail: Bool
    @State private var uiImage: UIImage?

    init(recipeID: UUID, imageData: Data?, imagePath: String? = nil, thumbnail: Bool = false) {
        self.recipeID = recipeID
        self.imageData = imageData
        self.imagePath = imagePath
        self.thumbnail = thumbnail
    }

    private static let placeholder: UIImage? = {
        guard let path = Bundle.main.path(forResource: "food", ofType: "jpg") else { return nil }
        return UIImage(contentsOfFile: path)
    }()

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let placeholder = Self.placeholder {
                Image(uiImage: placeholder)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Sourdough.Colors.sunken
                    Ph.image.regular
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                }
            }
        }
        .task(id: recipeID) {
            // 1. Check in-memory cache
            if let cached = RecipeImageCache.shared.image(for: recipeID, thumbnail: thumbnail) {
                uiImage = cached
                return
            }

            // 2. Check disk cache
            if let path = imagePath, !path.isEmpty {
                let diskData = thumbnail
                    ? RecipeImageDiskCache.loadThumb(for: path)
                    : RecipeImageDiskCache.load(for: path)
                if let diskData {
                    let id = recipeID
                    let isThumbnail = thumbnail
                    let decoded = await Task.detached {
                        UIImage(data: diskData)
                    }.value
                    if let decoded {
                        RecipeImageCache.shared.setImage(decoded, for: id, thumbnail: isThumbnail, cost: diskData.count)
                        withAnimation(.easeIn(duration: 0.2)) { uiImage = decoded }
                    }
                    return
                }
            }

            // 3. Try local imageData
            if let data = imageData {
                let id = recipeID
                let isThumbnail = thumbnail
                let decoded = await Task.detached {
                    isThumbnail
                        ? RecipeImageCache.generateThumbnail(from: data)
                        : UIImage(data: data)
                }.value
                if let decoded {
                    RecipeImageCache.shared.setImage(decoded, for: id, thumbnail: isThumbnail)
                    withAnimation(.easeIn(duration: 0.2)) { uiImage = decoded }
                }
                return
            }

            // 4. Download from Supabase storage
            if let path = imagePath, !path.isEmpty {
                let id = recipeID
                let isThumbnail = thumbnail
                do {
                    let data = try await SupabaseManager.client.storage
                        .from("recipe-images")
                        .download(path: path)

                    // Save full image to disk
                    RecipeImageDiskCache.save(data, for: path)

                    // Generate and save thumbnail
                    if let thumbImage = RecipeImageCache.generateThumbnail(from: data),
                       let thumbData = thumbImage.jpegData(compressionQuality: 0.7) {
                        RecipeImageDiskCache.saveThumb(thumbData, for: path)
                    }

                    let decoded = await Task.detached {
                        isThumbnail
                            ? RecipeImageCache.generateThumbnail(from: data)
                            : UIImage(data: data)
                    }.value
                    if let decoded {
                        RecipeImageCache.shared.setImage(decoded, for: id, thumbnail: isThumbnail, cost: data.count)
                        withAnimation(.easeIn(duration: 0.2)) { uiImage = decoded }
                    }
                } catch {
                    // Fall through to placeholder
                }
            }
        }
    }
}

// MARK: - Recipe Card

/// Bundles the `onReport`/`onRate`/`onSave` wiring every `RecipeCard` call site rebuilds from the
/// same `recipe`/`savedRecipesStore` pair — only the report/rate target state differs per caller.
@MainActor
struct RecipeCardActions {
    let onReport: (() -> Void)?
    let onRate: (() -> Void)?
    let onSave: () -> Void

    init(
        recipe: Recipe,
        savedRecipesStore: SavedRecipesStore,
        reportRecipe: @escaping (Recipe) -> Void,
        rateRecipe: @escaping (Recipe) -> Void
    ) {
        onReport = (recipe.isUserShared && recipe.createdBy != savedRecipesStore.userId?.uuidString)
            ? { reportRecipe(recipe) } : nil
        onRate = recipe.rating > 0 ? { rateRecipe(recipe) } : nil
        onSave = {
            savedRecipesStore.isSaved(recipe)
                ? savedRecipesStore.unsaveRecipe(recipe)
                : savedRecipesStore.saveRecipe(recipe)
        }
    }
}

struct RecipeCard: View, Equatable {
    let recipe: Recipe
    var showBadge: Bool = true
    var isSaved: Bool = false
    var onReport: (() -> Void)? = nil
    var onRate: (() -> Void)? = nil
    var onSave: (() -> Void)? = nil

    static func == (lhs: RecipeCard, rhs: RecipeCard) -> Bool {
        lhs.recipe.id == rhs.recipe.id
            && lhs.recipe.rating == rhs.recipe.rating
            && lhs.recipe.title == rhs.recipe.title
            && lhs.recipe.imagePath == rhs.recipe.imagePath
            && lhs.isSaved == rhs.isSaved
    }

    private var cardTags: [(text: String, isDiet: Bool)] {
        var labels: [(text: String, isDiet: Bool)] = []
        if recipe.dietType != "any" {
            labels.append((recipe.dietType.capitalized, true))
        }
        for r in recipe.dietaryRestrictions {
            labels.append((r, false))
        }
        return labels
    }

    private var ratingString: String {
        recipe.rating.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", recipe.rating)
            : String(format: "%.1f", recipe.rating)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(4/3, contentMode: .fit)
                .overlay {
                    if recipe.isAIGenerated && recipe.imageData == nil && recipe.imagePath == nil {
                        Image("AI_GEN")
                            .resizable()
                            .scaledToFill()
                    } else {
                        CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: true)
                    }
                }
                .clipped()
                .overlay(alignment: .topLeading) {
                    Text("\(recipe.timeMinutes) min")
                        .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                        .sourdoughTextStyle(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 4) {
                        if recipe.rating > 0 {
                            let ratingPill = HStack(spacing: 2) {
                                Ph.star.fill
                                    .frame(width: 9, height: 9)
                                    .foregroundStyle(Sourdough.Ramp.honeyDark)
                                Text(ratingString)
                                    .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                                    .sourdoughTextStyle(.caption)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())

                            if let onRate {
                                Button(action: onRate) { ratingPill }.buttonStyle(.plain)
                            } else {
                                ratingPill
                            }
                        }
                        if let onReport {
                            Button(action: onReport) {
                                Ph.flag.regular
                                    .frame(width: 11, height: 11)
                                    .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                                    .padding(6)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        if recipe.isAIGenerated {
                            AIGeneratedBadge()
                        }
                    }
                    .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
                .shadow(color: Sourdough.Ramp.linen900.opacity(0.08), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                Text(recipe.title)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.rowTitle)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let tags = cardTags
                if !tags.isEmpty {
                    let visibleTags = Array(tags.prefix(2))
                    let overflow = tags.count - visibleTags.count
                    HStack(spacing: 4) {
                        ForEach(visibleTags.indices, id: \.self) { i in
                            Text(visibleTags[i].text)
                                .foregroundStyle(Sourdough.Colors.onAction)
                                .sourdoughTextStyle(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(visibleTags[i].isDiet ? Sourdough.Ramp.sage500 : Sourdough.Ramp.honey600)
                                .clipShape(Capsule())
                        }
                        if overflow > 0 {
                            Text("+\(overflow) more")
                                .foregroundStyle(Sourdough.Colors.mutedInk)
                                .sourdoughTextStyle(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Sourdough.Colors.sunken)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct RecipesView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore

    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var showingSettings = false
    @State private var showingShareSheet = false
    @State private var selectedRecipe: Recipe?
    @State private var recipeToReport: Recipe?
    @State private var reportError: String?
    @State private var navigateToRecipe: Recipe?
    @State private var allergenPendingRecipe: Recipe?
    @State private var allergenWarningDetected: [String] = []
    @State private var ratingsRecipe: Recipe?
    @State private var showingFilterSheet = false
    @State private var selectedCuisine: Cuisine?
    @State private var maxPrepTime: Int?
    @State private var selectedIngredients: Set<String> = []
    @State private var selectedDietaryFilters: Set<String> = []
    @State private var cachedCommunityCategories: [RecipeCategory] = []
    @State private var showcaseItem: (recipe: Recipe, ingredient: Ingredient)? = nil
    @State private var useUpSoonRecipes: [Recipe] = []
    @State private var navigateToCategory: RecipeCategory?

    private enum QuickFilter: String, CaseIterable {
        case all = "All"
        case quick = "< 30 min"
        case vegan = "Vegan"
        case highProtein = "High Protein"
        case glutenFree = "Gluten-Free"
    }
    @State private var quickFilter: QuickFilter = .all

    private var hasActiveFilters: Bool {
        selectedCuisine != nil || maxPrepTime != nil || !selectedIngredients.isEmpty || !selectedDietaryFilters.isEmpty
    }

    private func applyFilters(_ recipes: [Recipe]) -> [Recipe] {
        var result = recipes

        if !debouncedSearch.isEmpty {
            let query = debouncedSearch.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.summary.lowercased().contains(query)
            }
        }

        if let cuisine = selectedCuisine {
            result = result.filter { $0.cuisine == cuisine }
        }

        if let max = maxPrepTime {
            result = result.filter { $0.timeMinutes <= max }
        }

        if !selectedIngredients.isEmpty {
            result = result.filter { recipe in
                let recipeIngredients = Set(recipe.ingredientsUsed.map { $0.name.lowercased() })
                return selectedIngredients.allSatisfy { selected in
                    recipeIngredients.contains(selected)
                }
            }
        }

        if !selectedDietaryFilters.isEmpty {
            result = result.filter { recipe in
                let recipeLabels = Set(recipe.dietaryRestrictions)
                if recipe.dietType != "any" { return selectedDietaryFilters.contains(recipe.dietType.capitalized) || !selectedDietaryFilters.isDisjoint(with: recipeLabels) }
                return !selectedDietaryFilters.isDisjoint(with: recipeLabels)
            }
        }

        return result
    }

    private var filteredCommunityRecipes: [Recipe] {
        applyQuickFilter(applyFilters(savedRecipesStore.communityRecipes))
    }

    // Computed once from pantry + community recipes (see recomputeUseUpMatches), not on every render.
    private func recomputeUseUpMatches() {
        let expiring = pantryStore.ingredients
            .filter { $0.expirationDate != nil && ($0.daysUntilExpiration ?? Int.max) >= 0 && ($0.daysUntilExpiration ?? Int.max) <= 5 }
            .sorted { ($0.daysUntilExpiration ?? Int.max) < ($1.daysUntilExpiration ?? Int.max) }

        guard !expiring.isEmpty else {
            showcaseItem = nil
            useUpSoonRecipes = []
            return
        }

        let community = savedRecipesStore.communityRecipes

        // Showcase: first expiring ingredient that has a matching community recipe.
        var showcase: (recipe: Recipe, ingredient: Ingredient)? = nil
        for ingredient in expiring {
            let name = ingredient.name.lowercased()
            if let match = community.first(where: { recipe in
                recipe.ingredientsUsed.contains(where: {
                    $0.name.lowercased().contains(name) || name.contains($0.name.lowercased())
                })
            }) {
                showcase = (match, ingredient)
                break
            }
        }
        showcaseItem = showcase

        // Use-up list: all community recipes using any expiring ingredient.
        let expiringNames = expiring.map { $0.name.lowercased() }
        useUpSoonRecipes = community.filter { recipe in
            recipe.ingredientsUsed.contains(where: { ing in
                expiringNames.contains(where: {
                    ing.name.lowercased().contains($0) || $0.contains(ing.name.lowercased())
                })
            })
        }
    }

    private func applyQuickFilter(_ recipes: [Recipe]) -> [Recipe] {
        switch quickFilter {
        case .all: return recipes
        case .quick: return recipes.filter { $0.timeMinutes <= 30 }
        case .vegan: return recipes.filter { $0.dietType == "vegan" }
        case .highProtein: return recipes.filter { $0.macros.proteinG >= 30 }
        case .glutenFree: return recipes.filter { $0.dietaryRestrictions.contains("Gluten-Free") }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            VStack(spacing: Sourdough.Spacing.rowInternals) {
                searchBar
                quickFilterChips
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.insideChip)

            recipeScrollContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Sourdough.Colors.canvas)
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
                .preferredColorScheme(session.preferredColorScheme)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareRecipeSheet()
        }
        .sheet(isPresented: $showingFilterSheet) {
            RecipeFilterSheet(
                selectedCuisine: $selectedCuisine,
                maxPrepTime: $maxPrepTime,
                selectedIngredients: $selectedIngredients,
                selectedDietaryFilters: $selectedDietaryFilters,
                allRecipes: savedRecipesStore.communityRecipes + savedRecipesStore.savedRecipes,
                pantryIngredients: pantryStore.ingredients
            )
        }
        .sheet(item: $selectedRecipe) { recipe in
            RecipePreviewSheet(recipe: recipe) {
                selectedRecipe = nil
                let detected = detectAllergens(
                    in: recipe,
                    userAllergies: session.currentUserAllergies,
                    customAllergy: session.currentUserCustomAllergy
                )
                if detected.isEmpty {
                    navigateToRecipe = recipe
                } else {
                    allergenWarningDetected = detected
                    allergenPendingRecipe = recipe
                }
            }
        }
        .sheet(item: $recipeToReport) { recipe in
            ReportContentSheet(subject: .recipe(name: recipe.title)) { category, description in
                Task {
                    do {
                        try await savedRecipesStore.reportRecipe(recipe, category: category, description: description)
                    } catch {
                        reportError = error.localizedDescription.contains("duplicate") || error.localizedDescription.contains("unique")
                            ? "You've already reported this recipe."
                            : "Failed to submit report. Please try again."
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .reportErrorAlert($reportError)
        .sheet(item: $allergenPendingRecipe) { recipe in
            AllergenWarningSheet(recipeName: recipe.title) {
                navigateToRecipe = recipe
            }
        }
        .navigationDestination(item: $navigateToRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .navigationDestination(item: $navigateToCategory) { category in
            CategoryRecipesView(category: category)
        }
        .navigationDestination(item: $ratingsRecipe) { recipe in
            RecipeRatingsView(recipe: recipe)
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                debouncedSearch = newValue
            }
        }
        .task {
            await savedRecipesStore.fetchRecipes()
        }
        .onAppear {
            cachedCommunityCategories = buildCategories(from: filteredCommunityRecipes)
            recomputeUseUpMatches()
        }
        .onChange(of: filteredCommunityRecipes) { _, newRecipes in
            cachedCommunityCategories = buildCategories(from: newRecipes)
        }
        .onChange(of: pantryStore.ingredients) { _, _ in
            recomputeUseUpMatches()
        }
        .onChange(of: savedRecipesStore.communityRecipes) { _, _ in
            recomputeUseUpMatches()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: Sourdough.Spacing.screenMargin) {
            Text("Recipes")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.title1)

            Spacer()

            Button {
                showingShareSheet = true
            } label: {
                HStack(spacing: Sourdough.Spacing.iconToLabel) {
                    Ph.plus.regular
                        .frame(width: 14, height: 14)
                    Text("Share")
                        .foregroundStyle(Sourdough.Colors.onAction)
                        .sourdoughTextStyle(.caption)
                }
                .foregroundStyle(Sourdough.Colors.onAction)
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .frame(height: 34)
                .background(Sourdough.Colors.action)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button { showingSettings = true } label: {
                Ph.gear.regular
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
            }
            .buttonStyle(.plain)
            NotificationBellButton()
            ProfileNavButton()
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.iconToLabel)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                Ph.magnifyingGlass.regular
                    .frame(width: 16, height: 16)
                    .foregroundStyle(Sourdough.Colors.faintInk)

                TextField("Search recipes", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.body)
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .frame(height: 48)
            .background(Sourdough.Colors.sunken)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

            Button {
                showingFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Ph.fadersHorizontal.regular
                        .frame(width: 16, height: 16)
                        .foregroundStyle(hasActiveFilters ? Sourdough.Ramp.sage600 : Sourdough.Colors.mutedInk)
                        .frame(width: 48, height: 48)
                        .background(Sourdough.Colors.sunken)
                        .overlay(
                            RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                                .stroke(hasActiveFilters ? Sourdough.Ramp.sage500 : Sourdough.Colors.interactiveBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                    if hasActiveFilters {
                        Circle()
                            .fill(Sourdough.Ramp.sage500)
                            .frame(width: 8, height: 8)
                            .offset(x: -4, y: 4)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Quick Filter Chips

    private var quickFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(QuickFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { quickFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .foregroundStyle(quickFilter == filter ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)
                            .padding(.horizontal, Sourdough.Spacing.rowInternals)
                            .frame(height: 34)
                            .background(quickFilter == filter ? Sourdough.Ramp.sage500 : Sourdough.Colors.sunken)
                            .overlay(
                                Capsule().stroke(
                                    quickFilter == filter ? Color.clear : Sourdough.Colors.interactiveBorder,
                                    lineWidth: 1
                                )
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.8),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - Scroll Content

    private var recipeScrollContent: some View {
        let hasContent = !filteredCommunityRecipes.isEmpty || showcaseItem != nil || !useUpSoonRecipes.isEmpty
        return Group {
            if !hasContent {
                VStack {
                    Spacer(minLength: Sourdough.Spacing.aboveSectionHead)
                    Text("No recipes match your filters.")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.subhead)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
                        if let item = showcaseItem {
                            showcaseCardView(recipe: item.recipe, ingredient: item.ingredient)
                                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                        }

                        if !useUpSoonRecipes.isEmpty {
                            useUpSection
                        }

                        ForEach(cachedCommunityCategories) { category in
                            categorySection(category)
                        }
                    }
                    .padding(.top, Sourdough.Spacing.rowInternals)
                    .padding(.bottom, Sourdough.Spacing.underTitle * 2)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [Sourdough.Colors.canvas, Sourdough.Colors.canvas.opacity(0)],
                        startPoint: .bottom, endPoint: .top
                    )
                    .frame(height: 48)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Showcase Card
    // The one dark "tonight's recipe" card that anchors the home screen (§2) — a fixed on-dark
    // surface like OnDarkHeroCard, but with its own top-badge/bookmark overlay layout that doesn't
    // fit that component's shape, so it's styled directly with the same dark tokens instead.

    @ViewBuilder
    private func showcaseCardView(recipe: Recipe, ingredient: Ingredient) -> some View {
        let days = ingredient.daysUntilExpiration ?? 0
        let urgencyLabel = days == 0 ? "TODAY" : days == 1 ? "1 DAY" : "\(days) DAYS"
        let pantryNames = Set(pantryStore.ingredients.map { $0.name.lowercased() })
        let matchCount = recipe.ingredientsUsed.filter { pantryNames.contains($0.name.lowercased()) }.count
        let isSaved = savedRecipesStore.isSaved(recipe)

        Button { selectedRecipe = recipe } label: {
            ZStack(alignment: .bottomLeading) {
                // Full-bleed background image
                Group {
                    if recipe.imagePath != nil || recipe.imageData != nil {
                        CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: false)
                            .scaledToFill()
                    } else {
                        LinearGradient(colors: [Sourdough.Ramp.darkCard, Sourdough.Ramp.darkCanvas], startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 220)
                .clipped()

                // Dark gradient from bottom
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.82), location: 0),
                        .init(color: .black.opacity(0.38), location: 0.55),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .bottom, endPoint: .top
                )

                // Top row: urgency badge + bookmark
                VStack {
                    HStack(alignment: .top) {
                        HStack(spacing: 5) {
                            Circle().fill(Sourdough.Ramp.urgentDarkLabel).frame(width: 6, height: 6)
                            Text("USE \(ingredient.name.uppercased()) · \(urgencyLabel)")
                                .foregroundStyle(Sourdough.Ramp.urgentDarkLabel)
                                .sourdoughTextStyle(.caption)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Sourdough.Ramp.urgentDarkTint)
                        .clipShape(Capsule())

                        Spacer()

                        Button {
                            if isSaved { savedRecipesStore.unsaveRecipe(recipe) }
                            else { savedRecipesStore.saveRecipe(recipe) }
                        } label: {
                            (isSaved ? Ph.bookmark.fill : Ph.bookmark.regular)
                                .frame(width: 15, height: 15)
                                .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                                .frame(width: 34, height: 34)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.top, Sourdough.Spacing.screenMargin)
                    Spacer()
                }

                // Bottom content
                VStack(alignment: .leading, spacing: 4) {
                    Text("TONIGHT'S PICK")
                        .foregroundStyle(Sourdough.Colors.heroMetaOnDark)
                        .sourdoughTextStyle(.sectionHead)

                    Text(recipe.title)
                        .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                        .sourdoughTextStyle(.title2)
                        .lineLimit(1)

                    Text(recipe.summary)
                        .foregroundStyle(Sourdough.Colors.heroMetaOnDark)
                        .sourdoughTextStyle(.caption)
                        .lineLimit(1)

                    HStack(spacing: Sourdough.Spacing.insideChip) {
                        if matchCount > 0 {
                            HStack(spacing: 4) {
                                Ph.check.bold.frame(width: 9, height: 9)
                                Text("\(matchCount)/\(recipe.ingredientsUsed.count) in pantry")
                                    .foregroundStyle(Sourdough.Ramp.sageDark)
                                    .sourdoughTextStyle(.caption)
                            }
                            .foregroundStyle(Sourdough.Ramp.sageDark)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Sourdough.Ramp.sageDark.opacity(0.18))
                            .clipShape(Capsule())
                        }

                        HStack(spacing: 4) {
                            Ph.clock.regular.frame(width: 10, height: 10)
                            Text("\(recipe.timeMinutes) min")
                                .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                                .sourdoughTextStyle(.caption)
                        }
                        .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())

                        Text("\(recipe.macros.calories)cal")
                            .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                            .sourdoughTextStyle(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.bottom, Sourdough.Spacing.screenMargin)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Use Up Section

    private var useUpSection: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use up before it expires")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.title2)
                    Text("\(useUpSoonRecipes.count) recipe\(useUpSoonRecipes.count == 1 ? "" : "s") for ingredients going bad soon")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.caption)
                }
                Spacer()
                Text("See all")
                    .foregroundStyle(Sourdough.Colors.actionInk)
                    .sourdoughTextStyle(.caption)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Sourdough.Spacing.rowInternals) {
                    ForEach(useUpSoonRecipes.prefix(10)) { recipe in
                        let actions = RecipeCardActions(
                            recipe: recipe,
                            savedRecipesStore: savedRecipesStore,
                            reportRecipe: { recipeToReport = $0 },
                            rateRecipe: { ratingsRecipe = $0 }
                        )
                        Button { selectedRecipe = recipe } label: {
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
                        .frame(width: 225)
                    }
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.8),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    // MARK: - Category Section

    private func categorySection(_ category: RecipeCategory) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Sourdough.Ramp.sage600)
                Text(category.title)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.title2)
                Spacer()
                if category.recipes.count > 5 {
                    Button { navigateToCategory = category } label: {
                        Text("See More")
                            .foregroundStyle(Sourdough.Colors.actionInk)
                            .sourdoughTextStyle(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Sourdough.Spacing.rowInternals) {
                    ForEach(category.recipes.prefix(5)) { recipe in
                        let actions = RecipeCardActions(
                            recipe: recipe,
                            savedRecipesStore: savedRecipesStore,
                            reportRecipe: { recipeToReport = $0 },
                            rateRecipe: { ratingsRecipe = $0 }
                        )
                        Button { selectedRecipe = recipe } label: {
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
                        .frame(width: 225)
                    }
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.8),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    // MARK: - Recipe List (grid, used for saved/your recipes)

    // MARK: - Categorized Community View

    struct RecipeCategory: Identifiable, Hashable {
        static func == (lhs: RecipeCategory, rhs: RecipeCategory) -> Bool { lhs.title == rhs.title }
        func hash(into hasher: inout Hasher) { hasher.combine(title) }

        var id: String { title }
        let title: String
        let icon: String
        let recipes: [Recipe]
    }

    private func buildCategories(from recipes: [Recipe]) -> [RecipeCategory] {
        var categories: [RecipeCategory] = []

        let lowCal = recipes.filter { $0.macros.calories <= 200 }
        if !lowCal.isEmpty {
            categories.append(RecipeCategory(title: "Low Calorie", icon: "flame", recipes: lowCal))
        }

        let highProtein = recipes.filter { $0.macros.proteinG >= 30 }
        if !highProtein.isEmpty {
            categories.append(RecipeCategory(title: "High Protein", icon: "bolt.fill", recipes: highProtein))
        }

        let quick = recipes.filter { $0.timeMinutes <= 15 }
        if !quick.isEmpty {
            categories.append(RecipeCategory(title: "Quick & Easy", icon: "clock", recipes: quick))
        }

        let grouped = Dictionary(grouping: recipes, by: \.cuisine)
        for cuisine in Cuisine.allCases {
            if let cuisineRecipes = grouped[cuisine], !cuisineRecipes.isEmpty {
                categories.append(RecipeCategory(title: cuisine.rawValue, icon: "fork.knife", recipes: cuisineRecipes))
            }
        }

        return categories
    }

}

// MARK: - Recipe Preview Sheet

struct RecipePreviewSheet: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let onViewFull: () -> Void

    @State private var showReportSheet = false
    @State private var reportError: String?

    private var pantryMatchCount: Int {
        let pantryNames = Set(pantryStore.ingredients.map { $0.name.lowercased() })
        return recipe.ingredientsUsed.filter { pantryNames.contains($0.name.lowercased()) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
                // Full-width hero image with drag handle overlaid
                ZStack(alignment: .top) {
                    CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: true)
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    Capsule()
                        .fill(.white.opacity(0.6))
                        .frame(width: 36, height: 5)
                        .padding(.top, Sourdough.Spacing.rowInternals)
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {

                        // Title + save + flag
                        HStack(alignment: .top, spacing: Sourdough.Spacing.insideChip) {
                            Text(recipe.title)
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.title1)
                            Spacer()
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                savedRecipesStore.isSaved(recipe)
                                    ? savedRecipesStore.unsaveRecipe(recipe)
                                    : savedRecipesStore.saveRecipe(recipe)
                            } label: {
                                (savedRecipesStore.isSaved(recipe) ? Ph.bookmark.fill : Ph.bookmark.regular)
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(savedRecipesStore.isSaved(recipe) ? Sourdough.Ramp.sage500 : Sourdough.Colors.faintInk)
                            }
                            .buttonStyle(.plain)
                            if recipe.isUserShared && recipe.createdBy != savedRecipesStore.userId?.uuidString {
                                Button { showReportSheet = true } label: {
                                    Ph.flag.regular
                                        .frame(width: 18, height: 18)
                                        .foregroundStyle(Sourdough.Colors.faintInk)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Summary
                        Text(recipe.summary)
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.body)

                        // Meta info
                        HStack(spacing: Sourdough.Spacing.screenMargin) {
                            Label { Text("\(recipe.timeMinutes) min") } icon: { Ph.clock.regular.frame(width: 14, height: 14) }
                            Label { Text("\(recipe.servings) servings") } icon: { Ph.users.regular.frame(width: 14, height: 14) }
                        }
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.subhead)

                        // Dietary pills
                        if !recipe.dietaryRestrictions.isEmpty || recipe.dietType != "any" {
                            FlowLayout(spacing: Sourdough.Spacing.iconToLabel) {
                                if recipe.dietType != "any" {
                                    Text(recipe.dietType.capitalized)
                                        .foregroundStyle(Sourdough.Ramp.sage600)
                                        .sourdoughTextStyle(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Sourdough.Ramp.sage100)
                                        .clipShape(Capsule())
                                }
                                ForEach(recipe.dietaryRestrictions, id: \.self) { restriction in
                                    Text(restriction)
                                        .foregroundStyle(Sourdough.Ramp.honey600)
                                        .sourdoughTextStyle(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Sourdough.Ramp.honey100)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        if recipe.rating > 0 {
                            HStack(spacing: Sourdough.Spacing.insideChip) {
                                StarRatingView(rating: recipe.rating, size: 14)
                                Text(recipe.rating.truncatingRemainder(dividingBy: 1) == 0
                                     ? String(format: "%.0f", recipe.rating)
                                     : String(format: "%.1f", recipe.rating))
                                    .foregroundStyle(Sourdough.Colors.mutedInk)
                                    .sourdoughTextStyle(.subhead)
                            }
                        }

                        if let displayName = recipe.createdByName ?? recipe.createdBy {
                            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                                Ph.userCircle.fill
                                    .frame(width: 12, height: 12)
                                Text("Created by \(displayName)")
                                    .foregroundStyle(Sourdough.Colors.faintInk)
                                    .sourdoughTextStyle(.caption)
                            }
                            .foregroundStyle(Sourdough.Colors.faintInk)
                        }

                        // Macros summary
                        HStack(spacing: Sourdough.Spacing.rowInternals) {
                            macroPill("Cal", value: "\(recipe.macros.calories)")
                            macroPill("Protein", value: "\(recipe.macros.proteinG)g")
                            macroPill("Carbs", value: "\(recipe.macros.carbsG)g")
                            macroPill("Fat", value: "\(recipe.macros.fatG)g")
                        }

                        // Ingredients preview
                        if !recipe.ingredientsUsed.isEmpty {
                            VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                                Text("Ingredients")
                                    .foregroundStyle(Sourdough.Colors.ink)
                                    .sourdoughTextStyle(.title2)

                                ForEach(Array(recipe.ingredientsUsed.prefix(5))) { ingredient in
                                    Text("\u{2022} \(ingredient.displayText)")
                                        .foregroundStyle(Sourdough.Colors.mutedInk)
                                        .sourdoughTextStyle(.subhead)
                                }

                                if recipe.ingredientsUsed.count > 5 {
                                    Text("+\(recipe.ingredientsUsed.count - 5) more")
                                        .foregroundStyle(Sourdough.Colors.faintInk)
                                        .sourdoughTextStyle(.subhead)
                                }

                                if pantryMatchCount > 0 {
                                    HStack(spacing: Sourdough.Spacing.iconToLabel) {
                                        Ph.sealCheck.fill
                                            .frame(width: 12, height: 12)
                                            .foregroundStyle(Sourdough.Ramp.sage600)
                                        Text("You have \(pantryMatchCount) of \(recipe.ingredientsUsed.count) ingredients")
                                            .foregroundStyle(Sourdough.Ramp.sage600)
                                            .sourdoughTextStyle(.subhead)
                                    }
                                    .padding(.top, Sourdough.Spacing.iconToLabel)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.top, Sourdough.Spacing.screenMargin)
                }

                // View Full Recipe button
                Button(action: onViewFull) {
                    Text("View Full Recipe")
                        .foregroundStyle(Sourdough.Colors.onAction)
                        .sourdoughTextStyle(.rowTitle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Sourdough.Colors.action)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.rowInternals)
            }
        .background(Sourdough.Colors.canvas)
        .sheet(isPresented: $showReportSheet) {
            ReportContentSheet(subject: .recipe(name: recipe.title)) { category, description in
                Task {
                    do {
                        try await savedRecipesStore.reportRecipe(recipe, category: category, description: description)
                    } catch {
                        reportError = error.localizedDescription.contains("duplicate") || error.localizedDescription.contains("unique")
                            ? "You've already reported this recipe."
                            : "Failed to submit report. Please try again."
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .reportErrorAlert($reportError)
    }

    private func macroPill(_ label: String, value: String) -> some View {
        VStack(spacing: Sourdough.Spacing.iconToLabel) {
            Text(value)
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.numeric)
            Text(label)
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Sourdough.Spacing.insideChip)
        .background(Sourdough.Colors.sunken)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
    }
}

// MARK: - Recipe Filter Sheet

private struct RecipeFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCuisine: Cuisine?
    @Binding var maxPrepTime: Int?
    @Binding var selectedIngredients: Set<String>
    @Binding var selectedDietaryFilters: Set<String>
    let allRecipes: [Recipe]
    let pantryIngredients: [Ingredient]

    private var sortedPantryNames: [String] {
        pantryIngredients.map(\.name).sorted()
    }

    private var hasActiveFilters: Bool {
        selectedCuisine != nil || maxPrepTime != nil || !selectedIngredients.isEmpty || !selectedDietaryFilters.isEmpty
    }

    private static let prepTimeOptions: [(label: String, value: Int?)] = [
        ("Any", nil),
        ("15 min", 15),
        ("30 min", 30),
        ("45 min", 45),
        ("60 min", 60)
    ]

    private static let dietaryOptions: [String] = [
        "Vegetarian", "Vegan", "Pescatarian", "Keto", "Paleo",
        "Gluten-Free", "Nut-Free", "Dairy-Free", "Soy-Free", "Egg-Free", "Shellfish-Free", "Low Sodium"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.betweenBlocks)

            // Header
            HStack {
                Text("Filters")
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.title1)

                Spacer()

                if hasActiveFilters {
                    Button("Reset") {
                        selectedCuisine = nil
                        maxPrepTime = nil
                        selectedIngredients = []
                        selectedDietaryFilters = []
                    }
                    .foregroundStyle(Sourdough.Colors.actionInk)
                    .sourdoughTextStyle(.caption)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.betweenBlocks)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
                    // Ingredients filter
                    if !pantryIngredients.isEmpty {
                        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                            Text("Ingredients")
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.title2)

                            Text("Show recipes that use these pantry items")
                                .foregroundStyle(Sourdough.Colors.faintInk)
                                .sourdoughTextStyle(.subhead)

                            FlowLayout(spacing: Sourdough.Spacing.insideChip) {
                                ForEach(sortedPantryNames, id: \.self) { name in
                                    let key = name.lowercased()
                                    filterChip(name.capitalized, isSelected: selectedIngredients.contains(key)) {
                                        if selectedIngredients.contains(key) {
                                            selectedIngredients.remove(key)
                                        } else {
                                            selectedIngredients.insert(key)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Cuisine filter
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                        Text("Cuisine")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.title2)

                        FlowLayout(spacing: Sourdough.Spacing.insideChip) {
                            filterChip("All", isSelected: selectedCuisine == nil) {
                                selectedCuisine = nil
                            }

                            ForEach(Cuisine.allCases) { cuisine in
                                filterChip(cuisine.rawValue, isSelected: selectedCuisine == cuisine) {
                                    selectedCuisine = selectedCuisine == cuisine ? nil : cuisine
                                }
                            }
                        }
                    }

                    // Prep time filter
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                        Text("Max Prep Time")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.title2)

                        FlowLayout(spacing: Sourdough.Spacing.insideChip) {
                            ForEach(Self.prepTimeOptions, id: \.label) { option in
                                filterChip(option.label, isSelected: maxPrepTime == option.value) {
                                    maxPrepTime = option.value
                                }
                            }
                        }
                    }

                    // Dietary filter
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                        Text("Dietary")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.title2)

                        FlowLayout(spacing: Sourdough.Spacing.insideChip) {
                            ForEach(Self.dietaryOptions, id: \.self) { option in
                                filterChip(option, isSelected: selectedDietaryFilters.contains(option)) {
                                    if selectedDietaryFilters.contains(option) {
                                        selectedDietaryFilters.remove(option)
                                    } else {
                                        selectedDietaryFilters.insert(option)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            // Done button
            Button { dismiss() } label: {
                Text("Show Results")
                    .foregroundStyle(Sourdough.Colors.onAction)
                    .sourdoughTextStyle(.rowTitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Sourdough.Colors.action)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.rowInternals)
        }
        .background(Sourdough.Colors.canvas)
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.caption)
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .frame(height: 36)
                .background(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.sunken)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Sourdough.Colors.interactiveBorder, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
