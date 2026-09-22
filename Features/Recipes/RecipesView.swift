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

@MainActor
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
        for entry in inFlight.values { entry.task.cancel() }
        inFlight.removeAll()
        sourceFingerprints.removeAll()
        fullCache.removeAllObjects()
        thumbCache.removeAllObjects()
    }

    func removeImage(for id: UUID) {
        inFlight.removeValue(forKey: id)?.task.cancel()
        sourceFingerprints[id] = nil
        let key = id.uuidString as NSString
        fullCache.removeObject(forKey: key)
        thumbCache.removeObject(forKey: key)
    }

    func setImage(_ image: UIImage, for id: UUID, thumbnail: Bool = false) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height }
            ?? Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        let key = id.uuidString as NSString
        if thumbnail {
            thumbCache.setObject(image, forKey: key, cost: cost)
        } else {
            fullCache.setObject(image, forKey: key, cost: cost)
        }
    }

    private struct LoadedImages {
        let full: UIImage
        let thumbnail: UIImage
    }
    private struct ImageRequest {
        let token: UUID
        let path: String?
        let data: Data?
        let task: Task<LoadedImages?, Never>
    }
    private var inFlight: [UUID: ImageRequest] = [:]
    private var sourceFingerprints: [UUID: Int] = [:]

    func load(id: UUID, path: String?, data: Data?, thumbnail: Bool) async -> UIImage? {
        // A recipe can receive a new path or local image without changing its ID.
        var hasher = Hasher()
        hasher.combine(path)
        hasher.combine(data)
        let fingerprint = hasher.finalize()
        if let previous = sourceFingerprints[id], previous != fingerprint { removeImage(for: id) }
        sourceFingerprints[id] = fingerprint
        if let cached = image(for: id, thumbnail: thumbnail) { return cached }
        let request: ImageRequest
        if let existing = inFlight[id], existing.path == path, existing.data == data {
            request = existing
        } else {
            inFlight[id]?.task.cancel()
            let task = Task.detached(priority: .userInitiated) { () -> LoadedImages? in
                do {
                    let source: Data
                    let downloaded: Bool
                    if let data {
                        source = data
                        downloaded = false
                    } else if let path, let cached = RecipeImageDiskCache.load(for: path) {
                        source = cached
                        downloaded = false
                    } else if let path, !path.isEmpty {
                        source = try await SupabaseManager.client.storage.from("recipe-images").download(path: path)
                        downloaded = true
                    } else { return nil }
                    try Task.checkCancellation()
                    guard let full = Self.generateThumbnail(from: source, maxPixelSize: 1600) else { return nil }
                    let diskThumb = data == nil ? path.flatMap { RecipeImageDiskCache.loadThumb(for: $0) } : nil
                    guard let thumb = diskThumb.flatMap({ Self.generateThumbnail(from: $0) })
                        ?? Self.generateThumbnail(from: source) else { return nil }
                    try Task.checkCancellation()
                    if let path, downloaded {
                        RecipeImageDiskCache.save(source, for: path)
                    }
                    if let path, diskThumb == nil, data == nil,
                       let encoded = thumb.jpegData(compressionQuality: 0.7) {
                        try Task.checkCancellation()
                        RecipeImageDiskCache.saveThumb(encoded, for: path)
                    }
                    return LoadedImages(full: full, thumbnail: thumb)
                } catch { return nil }
            }
            request = ImageRequest(token: UUID(), path: path, data: data, task: task)
            inFlight[id] = request
        }
        let loaded = await request.task.value
        guard inFlight[id]?.token == request.token else {
            return request.task.isCancelled ? nil : image(for: id, thumbnail: thumbnail)
        }
        inFlight[id] = nil
        guard let loaded, !request.task.isCancelled else { return nil }
        setImage(loaded.full, for: id)
        setImage(loaded.thumbnail, for: id, thumbnail: true)
        return thumbnail ? loaded.thumbnail : loaded.full
    }

    nonisolated static func generateThumbnail(from data: Data, maxPixelSize: Int = 800) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Recipe Image Placeholder

/// The branded stand-in for a recipe image — shown while `CachedRecipeImage` loads, on load
/// failure, and for recipes that have no image at all. Dark gradient + a centered fork-knife
/// sized proportionally so it reads at any scale (row thumbnail through full hero).
struct RecipeImagePlaceholder: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Sourdough.Ramp.darkCard, Sourdough.Ramp.darkCanvas],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                let side = min(max(min(proxy.size.width, proxy.size.height) * 0.30, 16), 56)
                Ph.forkKnife.regular
                    .frame(width: side, height: side)
                    .foregroundStyle(Sourdough.Colors.heroTitleOnDark.opacity(0.85))
            }
        }
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

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RecipeImagePlaceholder()
            }
        }
        .task(id: ImageIdentity(id: recipeID, path: imagePath, data: imageData, thumbnail: thumbnail)) {
            uiImage = nil
            let loaded = await RecipeImageCache.shared.load(
                id: recipeID, path: imagePath, data: imageData, thumbnail: thumbnail
            )
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { uiImage = loaded }
        }
    }

    private struct ImageIdentity: Equatable {
        let id: UUID
        let path: String?
        let data: Data?
        let thumbnail: Bool
    }
}

// MARK: - Recipe Card

/// Bundles the `onReport`/`onRate`/`onSave` wiring every `RecipeCard` call site rebuilds from the
/// same `recipe`/`savedRecipesStore` pair — only the report/rate target state differs per caller.
@MainActor
struct RecipeCardActions {
    let onReportRecipe: (() -> Void)?
    let onReportUser: (() -> Void)?
    let onRate: (() -> Void)?
    let onSave: () -> Void

    init(
        recipe: Recipe,
        savedRecipesStore: SavedRecipesStore,
        reportTarget: @escaping (ReportTarget) -> Void,
        rateRecipe: @escaping (Recipe) -> Void,
        presentSaveFlow: @escaping (Recipe) -> Void
    ) {
        let canReport = recipe.isUserShared && recipe.createdBy != savedRecipesStore.userId?.uuidString
        onReportRecipe = canReport ? { reportTarget(.recipe(recipe)) } : nil
        onReportUser = canReport ? {
            guard let creatorIdString = recipe.createdBy, let creatorId = UUID(uuidString: creatorIdString) else { return }
            reportTarget(.user(id: creatorId, nickname: recipe.createdByName ?? "this user"))
        } : nil
        onRate = recipe.rating > 0 ? { rateRecipe(recipe) } : nil
        onSave = {
            if savedRecipesStore.isSaved(recipe) {
                savedRecipesStore.unsaveRecipe(recipe)
            } else {
                presentSaveFlow(recipe)
            }
        }
    }
}

struct RecipeCard: View, Equatable {
    let recipe: Recipe
    var showBadge: Bool = true
    var isSaved: Bool = false
    var imageAspectRatio: CGFloat = 4 / 3
    var onReportRecipe: (() -> Void)? = nil
    var onReportUser: (() -> Void)? = nil
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
                .aspectRatio(imageAspectRatio, contentMode: .fit)
                .overlay {
                    if recipe.imageData == nil && recipe.imagePath == nil {
                        RecipeImagePlaceholder()
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
                        if onReportRecipe != nil || onReportUser != nil {
                            Menu {
                                if let onReportRecipe {
                                    Button(action: onReportRecipe) {
                                        Label("Report Recipe", systemImage: "flag")
                                    }
                                }
                                if let onReportUser {
                                    Button(action: onReportUser) {
                                        Label("Report User", systemImage: "person.fill.xmark")
                                    }
                                }
                            } label: {
                                Ph.flag.regular
                                    .frame(width: 11, height: 11)
                                    .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                                    .padding(6)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Circle())
                            }
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
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(recipe.summary)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.subhead)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let tags = cardTags
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
                .frame(height: 24, alignment: .leading)
            }
            .padding(.horizontal, 2)
        }
    }
}

struct RecipesView: View {
    var isActiveTab: Bool = true
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore

    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var showingShareSheet = false
    @State private var showCookbook = false
    @State private var selectedRecipe: Recipe?
    @State private var reportTarget: ReportTarget?
    @State private var reportError: String?
    @State private var navigateToRecipe: Recipe?
    @State private var allergenPendingRecipe: Recipe?
    @State private var allergenWarningDetected: [String] = []
    @State private var ratingsRecipe: Recipe?
    @State private var recipePendingSaveFlow: Recipe?
    @State private var recipePendingCollectionPick: Recipe?
    @State private var showingFilterSheet = false
    @State private var selectedCuisine: Cuisine?
    @State private var maxPrepTime: Int?
    @State private var selectedIngredients: Set<String> = []
    @State private var selectedDietaryFilters: Set<String> = []
    @State private var cachedGeneralCategories: [RecipeCategory] = []
    @State private var cachedCuisineCategories: [RecipeCategory] = []
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

    // Discovery sections (server-wide, via fetchDiscoverySections) give the screen a
    // full-catalog head start on first load — a rare cuisine shows up immediately
    // instead of waiting to coincidentally paginate into communityRecipes. They're
    // seeded into cachedGeneralCategories/cachedCuisineCategories once (see
    // seedCategoriesFromDiscovery, called from .task) via the same reconcile() used for
    // pagination growth, so scrolling to load more community recipes keeps extending the
    // same rendered categories afterward instead of writing to a separate, unread state.
    // The general-category list itself lives in SavedRecipesStore.generalCategorySpecs —
    // one shared definition instead of a second copy here that could drift out of sync.

    private func seedCategoriesFromDiscovery() {
        let general = SavedRecipesStore.generalCategorySpecs.compactMap { spec -> RecipeCategory? in
            guard let recipes = savedRecipesStore.discoveryGeneralRecipes[spec.title], !recipes.isEmpty else { return nil }
            return RecipeCategory(title: spec.title, icon: spec.icon, recipes: recipes, filter: spec.filter)
        }
        let cuisine = savedRecipesStore.discoveryCuisineOrder.compactMap { cuisine -> RecipeCategory? in
            guard let recipes = savedRecipesStore.discoveryCuisineRecipes[cuisine], !recipes.isEmpty else { return nil }
            return RecipeCategory(title: cuisine.rawValue, icon: "fork.knife", recipes: recipes, filter: .cuisine(cuisine))
        }
        cachedGeneralCategories = reconcile(existing: cachedGeneralCategories, updated: general)
        cachedCuisineCategories = reconcile(existing: cachedCuisineCategories, updated: cuisine)
    }

    private func applyFilters(_ recipes: [Recipe]) -> [Recipe] {
        var result = recipes

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

            Group {
                if debouncedSearch.isEmpty {
                    recipeScrollContent
                } else {
                    searchResultsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Sourdough.Colors.canvas)
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
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
        .sheet(item: $recipePendingSaveFlow) { recipe in
            SaveChoiceSheet(
                onSaveToCollection: {
                    recipePendingSaveFlow = nil
                    recipePendingCollectionPick = recipe
                },
                onJustSave: {
                    savedRecipesStore.saveRecipe(recipe)
                    recipePendingSaveFlow = nil
                }
            )
            .presentationDetents([.height(220)])
        }
        .sheet(item: $recipePendingCollectionPick) { recipe in
            CollectionPickerSheet(recipe: recipe) {
                recipePendingCollectionPick = nil
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $reportTarget) { target in
            ReportContentSheet(subject: target.subject) { category, description in
                Task {
                    do {
                        switch target {
                        case .recipe(let recipe):
                            try await savedRecipesStore.reportRecipe(recipe, category: category, description: description)
                        case .user(let id, _):
                            try await savedRecipesStore.reportUser(id, category: category, description: description)
                        }
                    } catch {
                        reportError = error.localizedDescription.contains("duplicate") || error.localizedDescription.contains("unique")
                            ? "You've already submitted this report."
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
        .navigationDestination(isPresented: $showCookbook) {
            CookbookView()
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                debouncedSearch = newValue
                await savedRecipesStore.searchRecipes(query: newValue)
            }
        }
        .task(id: isActiveTab) {
            guard isActiveTab else {
                searchDebounceTask?.cancel()
                return
            }
            let built = buildCategories(from: filteredCommunityRecipes)
            cachedGeneralCategories = reconcile(existing: cachedGeneralCategories, updated: built.general)
            cachedCuisineCategories = reconcile(existing: cachedCuisineCategories, updated: built.cuisine)
            recomputeUseUpMatches()
            async let recipesTask: Void = savedRecipesStore.fetchRecipes()
            async let discoveryTask: Void = savedRecipesStore.fetchDiscoverySections()
            _ = await (recipesTask, discoveryTask)
            guard !Task.isCancelled else { return }
            if searchText != debouncedSearch {
                debouncedSearch = searchText
                await savedRecipesStore.searchRecipes(query: searchText)
                guard !Task.isCancelled else { return }
            }
            recomputeUseUpMatches()
            seedCategoriesFromDiscovery()
        }
        .onChange(of: filteredCommunityRecipes) { _, newRecipes in
            guard isActiveTab else { return }
            let built = buildCategories(from: newRecipes)
            cachedGeneralCategories = reconcile(existing: cachedGeneralCategories, updated: built.general)
            cachedCuisineCategories = reconcile(existing: cachedCuisineCategories, updated: built.cuisine)
        }
        .onChange(of: pantryStore.ingredients) { _, _ in
            guard isActiveTab else { return }
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
                    Ph.plus.bold
                        .frame(width: 16, height: 16)
                    Text("Share")
                        .foregroundStyle(Sourdough.Colors.onAction)
                        .sourdoughTextStyle(.numeric)
                }
                .foregroundStyle(Sourdough.Colors.onAction)
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .frame(height: 40)
                .background(Sourdough.Colors.action)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                showCookbook = true
            } label: {
                Ph.bookOpenText.regular
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .frame(width: 40, height: 40)
                    .background(Sourdough.Colors.sunken)
                    .clipShape(Circle())
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
        HStack(spacing: Sourdough.Spacing.insideChip) {
            ForEach(QuickFilter.allCases, id: \.self) { filter in
                SelectableChip(label: filter.rawValue, isSelected: quickFilter == filter, size: .medium) {
                    withAnimation(.easeInOut(duration: 0.2)) { quickFilter = filter }
                }
            }
        }
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

                        if !cachedGeneralCategories.isEmpty {
                            Text("QUICK PICKS")
                                .foregroundStyle(Sourdough.Colors.faintInk)
                                .sourdoughTextStyle(.sectionHead)
                                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            ForEach(cachedGeneralCategories) { category in
                                categorySection(category)
                                Divider()
                                    .foregroundStyle(Sourdough.Colors.hairline)
                                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            }
                        }

                        if !cachedCuisineCategories.isEmpty {
                            Text("CUISINES")
                                .foregroundStyle(Sourdough.Colors.faintInk)
                                .sourdoughTextStyle(.sectionHead)
                                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            ForEach(cachedCuisineCategories) { category in
                                categorySection(category)
                                if category.id != cachedCuisineCategories.last?.id {
                                    Divider()
                                        .foregroundStyle(Sourdough.Colors.hairline)
                                        .padding(.horizontal, Sourdough.Spacing.screenMargin)
                                }
                            }
                        }

                        if savedRecipesStore.hasMoreCommunityRecipes {
                            HStack {
                                Spacer()
                                ProgressView().padding(.vertical, Sourdough.Spacing.screenMargin)
                                Spacer()
                            }
                            .task(id: isActiveTab) {
                                guard isActiveTab else { return }
                                await savedRecipesStore.fetchMoreCommunityRecipes()
                            }
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

    // MARK: - Search Results (paginated, server-side)

    private var searchResultsList: some View {
        Group {
            if savedRecipesStore.isSearching && savedRecipesStore.searchResults.isEmpty {
                VStack {
                    Spacer(minLength: Sourdough.Spacing.aboveSectionHead)
                    ProgressView()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if savedRecipesStore.searchResults.isEmpty {
                VStack {
                    Spacer(minLength: Sourdough.Spacing.aboveSectionHead)
                    Text("No recipes match your search.")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.subhead)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals),
                                GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals)
                            ],
                            spacing: Sourdough.Spacing.rowInternals
                        ) {
                            ForEach(savedRecipesStore.searchResults) { recipe in
                                let actions = RecipeCardActions(
                                    recipe: recipe,
                                    savedRecipesStore: savedRecipesStore,
                                    reportTarget: { reportTarget = $0 },
                                    rateRecipe: { ratingsRecipe = $0 },
                                    presentSaveFlow: { recipePendingSaveFlow = $0 }
                                )
                                Button { selectedRecipe = recipe } label: {
                                    RecipeCard(
                                        recipe: recipe,
                                        showBadge: false,
                                        isSaved: savedRecipesStore.isSaved(recipe),
                                        onReportRecipe: actions.onReportRecipe,
                                        onReportUser: actions.onReportUser,
                                        onRate: actions.onRate,
                                        onSave: actions.onSave
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if savedRecipesStore.hasMoreSearchResults {
                            HStack {
                                Spacer()
                                ProgressView().padding(.vertical, Sourdough.Spacing.screenMargin)
                                Spacer()
                            }
                            .task(id: isActiveTab) {
                                guard isActiveTab else { return }
                                await savedRecipesStore.fetchMoreSearchResults(query: debouncedSearch)
                            }
                        }
                    }
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.top, Sourdough.Spacing.rowInternals)
                    .padding(.bottom, Sourdough.Spacing.underTitle * 2)
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
        let matchableIngredients = recipe.ingredientsUsed.filter { !PantryStaples.isStaple($0.name) }
        let matchCount = matchableIngredients.filter { pantryNames.contains($0.name.lowercased()) }.count
        let isSaved = savedRecipesStore.isSaved(recipe)

        Button { selectedRecipe = recipe } label: {
            ZStack(alignment: .bottomLeading) {
                // Full-bleed background image
                Group {
                    if recipe.imagePath != nil || recipe.imageData != nil {
                        CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: false)
                            .scaledToFill()
                    } else {
                        RecipeImagePlaceholder()
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
                            else { recipePendingSaveFlow = recipe }
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
                                Text("\(matchCount)/\(matchableIngredients.count) in pantry")
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
                            reportTarget: { reportTarget = $0 },
                            rateRecipe: { ratingsRecipe = $0 },
                            presentSaveFlow: { recipePendingSaveFlow = $0 }
                        )
                        Button { selectedRecipe = recipe } label: {
                            RecipeCard(
                                recipe: recipe,
                                showBadge: false,
                                isSaved: savedRecipesStore.isSaved(recipe),
                                onReportRecipe: actions.onReportRecipe,
                                onReportUser: actions.onReportUser,
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
                        .init(color: .black, location: 0.92),
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
                    .font(.system(size: 20))
                    .foregroundStyle(Sourdough.Ramp.sage600)
                Text(category.title)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .font(.custom("Figtree", size: 26))
                    .fontWeight(.semibold)
                Spacer()
                if category.recipes.count > 5 {
                    NavChipButton(icon: Ph.arrowRight.bold) { navigateToCategory = category }
                        .accessibilityLabel("See more \(category.title) recipes")
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Sourdough.Spacing.rowInternals) {
                    ForEach(category.recipes.prefix(5)) { recipe in
                        let actions = RecipeCardActions(
                            recipe: recipe,
                            savedRecipesStore: savedRecipesStore,
                            reportTarget: { reportTarget = $0 },
                            rateRecipe: { ratingsRecipe = $0 },
                            presentSaveFlow: { recipePendingSaveFlow = $0 }
                        )
                        Button { selectedRecipe = recipe } label: {
                            RecipeCard(
                                recipe: recipe,
                                showBadge: false,
                                isSaved: savedRecipesStore.isSaved(recipe),
                                onReportRecipe: actions.onReportRecipe,
                                onReportUser: actions.onReportUser,
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
                        .init(color: .black, location: 0.92),
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
        let filter: SavedRecipesStore.CategoryFilter
    }

    private func buildCategories(from recipes: [Recipe]) -> (general: [RecipeCategory], cuisine: [RecipeCategory]) {
        var general: [RecipeCategory] = []

        for spec in SavedRecipesStore.generalCategorySpecs {
            let matching = recipes.filter { spec.filter.matches($0) }
            if !matching.isEmpty {
                general.append(RecipeCategory(title: spec.title, icon: spec.icon, recipes: matching, filter: spec.filter))
            }
        }

        var cuisineCategories: [RecipeCategory] = []

        let asianCuisines: Set<Cuisine> = [.asian, .chinese, .japanese, .korean, .thai, .vietnamese, .filipino, .indian]
        let asianRecipes = recipes.filter { asianCuisines.contains($0.cuisine) }
        if !asianRecipes.isEmpty {
            cuisineCategories.append(RecipeCategory(title: "Asian", icon: "fork.knife", recipes: asianRecipes, filter: .cuisineGroup(asianCuisines)))
        }

        let middleEasternCuisines: Set<Cuisine> = [.middleEastern, .turkish]
        let middleEasternRecipes = recipes.filter { middleEasternCuisines.contains($0.cuisine) }
        if !middleEasternRecipes.isEmpty {
            cuisineCategories.append(RecipeCategory(title: "Middle Eastern", icon: "fork.knife", recipes: middleEasternRecipes, filter: .cuisineGroup(middleEasternCuisines)))
        }

        let grouped = Dictionary(grouping: recipes, by: \.cuisine)
        for cuisine in Cuisine.allCases where cuisine != .asian && cuisine != .middleEastern {
            if let cuisineRecipes = grouped[cuisine], !cuisineRecipes.isEmpty {
                cuisineCategories.append(RecipeCategory(title: cuisine.rawValue, icon: "fork.knife", recipes: cuisineRecipes, filter: .cuisine(cuisine)))
            }
        }

        return (general, cuisineCategories)
    }

    // Merges a freshly-built category list into the cached one without reordering or
    // dropping sections the user has already scrolled past — categories that still exist
    // keep their position (and just grow their recipes), brand-new categories are only
    // ever appended at the end. This keeps pagination from inserting a new section above
    // content already on screen.
    private func reconcile(existing: [RecipeCategory], updated: [RecipeCategory]) -> [RecipeCategory] {
        let updatedByTitle = Dictionary(uniqueKeysWithValues: updated.map { ($0.title, $0) })
        var result: [RecipeCategory] = []
        var seen = Set<String>()
        for category in existing {
            if let refreshed = updatedByTitle[category.title] {
                result.append(refreshed)
                seen.insert(category.title)
            }
        }
        for category in updated where !seen.contains(category.title) {
            result.append(category)
        }
        return result
    }

}

// MARK: - Recipe Preview Sheet

struct RecipePreviewSheet: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let onViewFull: () -> Void

    @State private var reportTarget: ReportTarget?
    @State private var reportError: String?
    @State private var showSaveChoiceSheet = false
    @State private var showCollectionPicker = false
    @State private var pendingSaveSheetWork: DispatchWorkItem?

    private var matchableIngredients: [RecipeIngredient] {
        recipe.ingredientsUsed.filter { !PantryStaples.isStaple($0.name) }
    }

    private var pantryMatchCount: Int {
        let pantryNames = Set(pantryStore.ingredients.map { $0.name.lowercased() })
        return matchableIngredients.filter { pantryNames.contains($0.name.lowercased()) }.count
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
                                if savedRecipesStore.isSaved(recipe) {
                                    savedRecipesStore.unsaveRecipe(recipe)
                                } else {
                                    showSaveChoiceSheet = true
                                }
                            } label: {
                                (savedRecipesStore.isSaved(recipe) ? Ph.bookmark.fill : Ph.bookmark.regular)
                                    .frame(width: 22, height: 22)
                                    .foregroundStyle(savedRecipesStore.isSaved(recipe) ? Sourdough.Ramp.sage500 : Sourdough.Colors.faintInk)
                            }
                            .buttonStyle(.plain)
                            if recipe.isUserShared && recipe.createdBy != savedRecipesStore.userId?.uuidString {
                                Menu {
                                    Button {
                                        reportTarget = .recipe(recipe)
                                    } label: {
                                        Label("Report Recipe", systemImage: "flag")
                                    }
                                    Button {
                                        guard let creatorIdString = recipe.createdBy, let creatorId = UUID(uuidString: creatorIdString) else { return }
                                        reportTarget = .user(id: creatorId, nickname: recipe.createdByName ?? "this user")
                                    } label: {
                                        Label("Report User", systemImage: "person.fill.xmark")
                                    }
                                } label: {
                                    Ph.flag.regular
                                        .frame(width: 22, height: 22)
                                        .foregroundStyle(Sourdough.Colors.faintInk)
                                }
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

                        HStack(spacing: Sourdough.Spacing.insideChip) {
                            StarRatingView(rating: recipe.rating, size: 16)
                            if recipe.rating > 0 {
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
                                        Text("You have \(pantryMatchCount) of \(matchableIngredients.count) ingredients")
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
        .sheet(item: $reportTarget) { target in
            ReportContentSheet(subject: target.subject) { category, description in
                Task {
                    do {
                        switch target {
                        case .recipe(let recipe):
                            try await savedRecipesStore.reportRecipe(recipe, category: category, description: description)
                        case .user(let id, _):
                            try await savedRecipesStore.reportUser(id, category: category, description: description)
                        }
                    } catch {
                        reportError = error.localizedDescription.contains("duplicate") || error.localizedDescription.contains("unique")
                            ? "You've already submitted this report."
                            : "Failed to submit report. Please try again."
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSaveChoiceSheet) {
            SaveChoiceSheet(
                onSaveToCollection: {
                    showSaveChoiceSheet = false
                    pendingSaveSheetWork?.cancel()
                    let work = DispatchWorkItem { showCollectionPicker = true }
                    pendingSaveSheetWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
                },
                onJustSave: {
                    savedRecipesStore.saveRecipe(recipe)
                    showSaveChoiceSheet = false
                }
            )
            .presentationDetents([.height(220)])
        }
        .sheet(isPresented: $showCollectionPicker) {
            CollectionPickerSheet(recipe: recipe) {
                showCollectionPicker = false
            }
            .presentationDetents([.medium, .large])
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

private let filterPrepTimeOptions: [(label: String, value: Int?)] = [
    ("Any", nil),
    ("15 min", 15),
    ("30 min", 30),
    ("45 min", 45),
    ("60 min", 60)
]

private let filterDietaryOptions: [String] = [
    "Vegetarian", "Vegan", "Pescatarian", "Keto", "Paleo",
    "Gluten-Free", "Nut-Free", "Dairy-Free", "Soy-Free", "Egg-Free", "Shellfish-Free", "Low Sodium"
]

// MARK: - Filter field container (mirrors GenerateView's OptionsRow)

private struct FilterOptionsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            Text(label)
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.body)
            Spacer()
            Text(value)
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.subhead)
                .lineLimit(1)
            Ph.caretRight.regular
                .frame(width: 12, height: 12)
                .foregroundStyle(Sourdough.Colors.faintInk)
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .frame(height: 52)
        .background(Sourdough.Colors.sunken)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
        )
    }
}

// MARK: - Filter list-screen header + row (mirrors GenerateView's selectionPageHeader/selectionRow)

private func filterSelectionHeader(title: String, onBack: @escaping () -> Void) -> some View {
    HStack {
        Button(action: onBack) {
            Ph.caretLeft.regular
                .frame(width: 17, height: 17)
                .foregroundStyle(Sourdough.Colors.ink)
        }
        .buttonStyle(.plain)
        Spacer()
        Text(title)
            .foregroundStyle(Sourdough.Colors.ink)
            .sourdoughTextStyle(.title2)
        Spacer()
        Ph.caretLeft.regular
            .frame(width: 17, height: 17)
            .hidden()
    }
    .padding(.horizontal, Sourdough.Spacing.screenMargin)
    .padding(.vertical, Sourdough.Spacing.rowInternals)
}

private func filterSelectionRow(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            Group {
                if isSelected { Ph.checkCircle.fill } else { Ph.circle.regular }
            }
            .frame(width: 20, height: 20)
            .foregroundStyle(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.faintInk)

            Text(label)
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.body)

            Spacer()
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .frame(maxWidth: .infinity, minHeight: 60)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}

// MARK: - Filter list screens

private struct CuisineFilterListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCuisine: Cuisine?

    var body: some View {
        VStack(spacing: 0) {
            filterSelectionHeader(title: "Cuisine") { dismiss() }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    filterSelectionRow(label: "Any", isSelected: selectedCuisine == nil) {
                        selectedCuisine = nil
                        dismiss()
                    }
                    Divider().padding(.leading, Sourdough.Spacing.screenMargin)
                    ForEach(Array(Cuisine.allCases.enumerated()), id: \.element) { index, cuisine in
                        filterSelectionRow(label: cuisine.rawValue, isSelected: selectedCuisine == cuisine) {
                            selectedCuisine = cuisine
                            dismiss()
                        }
                        if index < Cuisine.allCases.count - 1 {
                            Divider().padding(.leading, Sourdough.Spacing.screenMargin)
                        }
                    }
                }
                .padding(.top, Sourdough.Spacing.insideChip)
                .padding(.bottom, Sourdough.Spacing.aboveSectionHead)
            }
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct PrepTimeFilterListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var maxPrepTime: Int?

    var body: some View {
        VStack(spacing: 0) {
            filterSelectionHeader(title: "Max Prep Time") { dismiss() }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(filterPrepTimeOptions.enumerated()), id: \.offset) { index, option in
                        filterSelectionRow(label: option.label, isSelected: maxPrepTime == option.value) {
                            maxPrepTime = option.value
                            dismiss()
                        }
                        if index < filterPrepTimeOptions.count - 1 {
                            Divider().padding(.leading, Sourdough.Spacing.screenMargin)
                        }
                    }
                }
                .padding(.top, Sourdough.Spacing.insideChip)
                .padding(.bottom, Sourdough.Spacing.aboveSectionHead)
            }
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct DietaryFilterListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDietaryFilters: Set<String>

    var body: some View {
        VStack(spacing: 0) {
            filterSelectionHeader(title: "Dietary") { dismiss() }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(filterDietaryOptions.enumerated()), id: \.offset) { index, option in
                        filterSelectionRow(label: option, isSelected: selectedDietaryFilters.contains(option)) {
                            if selectedDietaryFilters.contains(option) {
                                selectedDietaryFilters.remove(option)
                            } else {
                                selectedDietaryFilters.insert(option)
                            }
                        }
                        if index < filterDietaryOptions.count - 1 {
                            Divider().padding(.leading, Sourdough.Spacing.screenMargin)
                        }
                    }
                }
                .padding(.top, Sourdough.Spacing.insideChip)
                .padding(.bottom, Sourdough.Spacing.aboveSectionHead)
            }
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct IngredientFilterListView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIngredients: Set<String>
    let allNames: [String]

    var body: some View {
        VStack(spacing: 0) {
            filterSelectionHeader(title: "Ingredients") { dismiss() }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(allNames.enumerated()), id: \.offset) { index, name in
                        let key = name.lowercased()
                        filterSelectionRow(label: name.capitalized, isSelected: selectedIngredients.contains(key)) {
                            if selectedIngredients.contains(key) {
                                selectedIngredients.remove(key)
                            } else {
                                selectedIngredients.insert(key)
                            }
                        }
                        if index < allNames.count - 1 {
                            Divider().padding(.leading, Sourdough.Spacing.screenMargin)
                        }
                    }
                }
                .padding(.top, Sourdough.Spacing.insideChip)
                .padding(.bottom, Sourdough.Spacing.aboveSectionHead)
            }
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Filter sheet

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

    private var prepTimeLabel: String {
        filterPrepTimeOptions.first { $0.value == maxPrepTime }?.label ?? "Any"
    }

    private var ingredientsSummary: String {
        selectedIngredients.isEmpty ? "Any" : selectedIngredients.map { $0.capitalized }.sorted().joined(separator: ", ")
    }

    private var dietarySummary: String {
        selectedDietaryFilters.isEmpty ? "None" : selectedDietaryFilters.sorted().joined(separator: ", ")
    }

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

            NavigationStack {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Sourdough.Spacing.rowInternals) {
                        if !pantryIngredients.isEmpty {
                            NavigationLink {
                                IngredientFilterListView(selectedIngredients: $selectedIngredients, allNames: sortedPantryNames)
                            } label: {
                                FilterOptionsRow(label: "Ingredients", value: ingredientsSummary)
                            }
                            .buttonStyle(.plain)
                        }

                        NavigationLink {
                            CuisineFilterListView(selectedCuisine: $selectedCuisine)
                        } label: {
                            FilterOptionsRow(label: "Cuisine", value: selectedCuisine?.rawValue ?? "Any")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            PrepTimeFilterListView(maxPrepTime: $maxPrepTime)
                        } label: {
                            FilterOptionsRow(label: "Max Prep Time", value: prepTimeLabel)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            DietaryFilterListView(selectedDietaryFilters: $selectedDietaryFilters)
                        } label: {
                            FilterOptionsRow(label: "Dietary", value: dietarySummary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                }
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
}
