import SwiftUI

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
                    DS.ColorToken.bgTertiary
                    Image(systemName: "photo")
                        .font(.system(size: 24))
                        .foregroundStyle(DS.ColorToken.textTertiary)
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

private struct RecipeCard: View, Equatable {
    let recipe: Recipe

    static func == (lhs: RecipeCard, rhs: RecipeCard) -> Bool {
        lhs.recipe.id == rhs.recipe.id
            && lhs.recipe.rating == rhs.recipe.rating
            && lhs.recipe.title == rhs.recipe.title
            && lhs.recipe.imagePath == rhs.recipe.imagePath
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .aspectRatio(4/3, contentMode: .fit)
                .overlay {
                    if recipe.isAIGenerated && recipe.imageData == nil && recipe.imagePath == nil {
                        ZStack {
                            LinearGradient(
                                colors: [DS.ColorToken.primary, DS.ColorToken.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "fork.knife")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    } else {
                        CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: true)
                    }
                }
                .clipped()
                .overlay(alignment: .topLeading) {
                    Text("\(recipe.timeMinutes) min")
                        .font(.custom("Satoshi Variable", size: 11).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    if recipe.isAIGenerated {
                        AIGeneratedBadge()
                            .padding(8)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if recipe.rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(DS.ColorToken.warning)
                            Text(recipe.rating.truncatingRemainder(dividingBy: 1) == 0
                                 ? String(format: "%.0f", recipe.rating)
                                 : String(format: "%.1f", recipe.rating))
                                .font(.custom("Satoshi Variable", size: 11).weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                        .padding(8)
                    }
                }

            VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                Text(recipe.title)
                    .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)

                Text(recipe.summary.isEmpty ? " " : recipe.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !recipe.dietaryRestrictions.isEmpty || recipe.dietType != "any" {
                    let allLabels: [(text: String, isDiet: Bool)] = {
                        var labels: [(String, Bool)] = []
                        if recipe.dietType != "any" {
                            labels.append((recipe.dietType.capitalized, true))
                        }
                        for r in recipe.dietaryRestrictions {
                            labels.append((r, false))
                        }
                        return labels
                    }()
                    let maxVisible = 2
                    let visible = Array(allLabels.prefix(maxVisible))
                    let overflow = allLabels.count - maxVisible

                    HStack(spacing: 4) {
                        ForEach(visible.indices, id: \.self) { i in
                            Text(visible[i].text)
                                .font(.custom("Satoshi Variable", size: 9).weight(.semibold))
                                .foregroundStyle(visible[i].isDiet ? DS.ColorToken.accent : DS.ColorToken.primary)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(visible[i].isDiet ? DS.ColorToken.accentLight : DS.ColorToken.primaryLight)
                                .clipShape(Capsule())
                        }

                        if overflow > 0 {
                            Text("+\(overflow) more")
                                .font(.custom("Satoshi Variable", size: 9).weight(.semibold))
                                .foregroundStyle(DS.ColorToken.textTertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DS.ColorToken.bgSecondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(DS.ColorToken.borderDefault, lineWidth: 0.5)
                                )
                        }
                    }
                }
            }
            .padding(DS.Spacing.space2)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(DS.ColorToken.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

struct RecipesView: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore

    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var showingSettings = false
    @State private var showingShareSheet = false
    @State private var selectedRecipe: Recipe?
    @State private var navigateToRecipe: Recipe?
    @State private var showingFilterSheet = false
    @State private var selectedCuisine: Cuisine?
    @State private var maxPrepTime: Int?
    @State private var selectedIngredients: Set<String> = []
    @State private var selectedDietaryFilters: Set<String> = []
    @State private var cachedCommunityCategories: [RecipeCategory] = []
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

    private var showcaseItem: (recipe: Recipe, ingredient: Ingredient)? {
        let expiring = pantryStore.ingredients
            .filter { $0.expirationDate != nil && ($0.daysUntilExpiration ?? Int.max) >= 0 && ($0.daysUntilExpiration ?? Int.max) <= 5 }
            .sorted { ($0.daysUntilExpiration ?? Int.max) < ($1.daysUntilExpiration ?? Int.max) }
        for ingredient in expiring {
            let name = ingredient.name.lowercased()
            if let match = savedRecipesStore.communityRecipes.first(where: { recipe in
                recipe.ingredientsUsed.contains(where: {
                    $0.name.lowercased().contains(name) || name.contains($0.name.lowercased())
                })
            }) {
                return (match, ingredient)
            }
        }
        return nil
    }

    private var useUpSoonRecipes: [Recipe] {
        let expiringNames = pantryStore.ingredients
            .filter { $0.expirationDate != nil && ($0.daysUntilExpiration ?? Int.max) >= 0 && ($0.daysUntilExpiration ?? Int.max) <= 5 }
            .map { $0.name.lowercased() }
        guard !expiringNames.isEmpty else { return [] }
        return savedRecipesStore.communityRecipes.filter { recipe in
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

            VStack(spacing: DS.Spacing.space3) {
                searchBar
                quickFilterChips
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space4)
            .padding(.bottom, DS.Spacing.space2)

            recipeScrollContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(DS.ColorToken.bgPrimary)
        }
        .background(DS.ColorToken.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
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
                navigateToRecipe = recipe
            }
        }
        .navigationDestination(item: $navigateToRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .navigationDestination(item: $navigateToCategory) { category in
            CategoryRecipesView(category: category)
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
        }
        .onChange(of: filteredCommunityRecipes) { _, newRecipes in
            cachedCommunityCategories = buildCategories(from: newRecipes)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: DS.Spacing.space4) {
            Text("Recipes")
                .font(.custom("CalSans-Regular", size: 28))
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()

            Button {
                showingShareSheet = true
            } label: {
                HStack(spacing: DS.Spacing.space1) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Share")
                        .font(.custom("Satoshi Variable", size: 14).weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.space3)
                .frame(height: 34)
                .background(DS.ColorToken.primary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }
            .buttonStyle(.plain)
            NotificationBellButton()
            ProfileNavButton()
        }
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.top, DS.Spacing.space2)
        .padding(.bottom, DS.Spacing.space4)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: DS.Spacing.space2) {
            HStack(spacing: DS.Spacing.space2) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.ColorToken.textTertiary)

                TextField("Search recipes", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .appTextStyle(.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)
            }
            .padding(.horizontal, DS.Spacing.space3)
            .frame(height: 48)
            .background(DS.ColorToken.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                    .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))

            Button {
                showingFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(hasActiveFilters ? DS.ColorToken.primary : DS.ColorToken.textSecondary)
                        .frame(width: 48, height: 48)
                        .background(DS.ColorToken.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                .stroke(hasActiveFilters ? DS.ColorToken.primary : DS.ColorToken.borderDefault, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))

                    if hasActiveFilters {
                        Circle()
                            .fill(DS.ColorToken.primary)
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
            HStack(spacing: DS.Spacing.space2) {
                ForEach(QuickFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { quickFilter = filter }
                    } label: {
                        Text(filter.rawValue)
                            .font(.custom("Satoshi Variable", size: 13).weight(.medium))
                            .foregroundStyle(quickFilter == filter ? .white : DS.ColorToken.textSecondary)
                            .padding(.horizontal, DS.Spacing.space3)
                            .frame(height: 34)
                            .background(quickFilter == filter ? DS.ColorToken.accent : DS.ColorToken.bgSecondary)
                            .overlay(
                                Capsule().stroke(
                                    quickFilter == filter ? Color.clear : DS.ColorToken.borderDefault,
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
                    Spacer(minLength: DS.Spacing.space8)
                    Text("No recipes match your filters.")
                        .appTextStyle(.bodySM)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: DS.Spacing.space6) {
                        if let item = showcaseItem {
                            showcaseCardView(recipe: item.recipe, ingredient: item.ingredient)
                                .padding(.horizontal, DS.Spacing.space5)
                        }

                        if !useUpSoonRecipes.isEmpty {
                            useUpSection
                        }

                        ForEach(cachedCommunityCategories) { category in
                            categorySection(category)
                        }
                    }
                    .padding(.top, DS.Spacing.space3)
                    .padding(.bottom, DS.Spacing.space24)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [DS.ColorToken.bgPrimary, DS.ColorToken.bgPrimary.opacity(0)],
                        startPoint: .bottom, endPoint: .top
                    )
                    .frame(height: 48)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    // MARK: - Showcase Card

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
                        LinearGradient(colors: [DS.ColorToken.primary, DS.ColorToken.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
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
                            Circle().fill(DS.ColorToken.warning).frame(width: 6, height: 6)
                            Text("USE \(ingredient.name.uppercased()) · \(urgencyLabel)")
                                .font(.custom("Satoshi Variable", size: 10).weight(.bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color(red: 0.78, green: 0.38, blue: 0.05).opacity(0.9))
                        .clipShape(Capsule())

                        Spacer()

                        Button {
                            if isSaved { savedRecipesStore.unsaveRecipe(recipe) }
                            else { savedRecipesStore.saveRecipe(recipe) }
                        } label: {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DS.Spacing.space4)
                    .padding(.top, DS.Spacing.space4)
                    Spacer()
                }

                // Bottom content
                VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                    Text("TONIGHT'S PICK")
                        .font(.custom("Satoshi Variable", size: 10).weight(.bold))
                        .foregroundStyle(.white.opacity(0.65))
                        .tracking(0.8)

                    Text(recipe.title)
                        .font(.custom("CalSans-Regular", size: 22))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(recipe.summary)
                        .font(.custom("Satoshi Variable", size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)

                    HStack(spacing: DS.Spacing.space2) {
                        if matchCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .bold))
                                Text("\(matchCount)/\(recipe.ingredientsUsed.count) in pantry")
                                    .font(.custom("Satoshi Variable", size: 11).weight(.semibold))
                            }
                            .foregroundStyle(DS.ColorToken.success)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(DS.ColorToken.success.opacity(0.18))
                            .clipShape(Capsule())
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "clock").font(.system(size: 10))
                            Text("\(recipe.timeMinutes) min")
                                .font(.custom("Satoshi Variable", size: 11).weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())

                        Text("\(recipe.macros.calories)cal")
                            .font(.custom("Satoshi Variable", size: 11).weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Capsule())
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, DS.Spacing.space4)
                .padding(.bottom, DS.Spacing.space4)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Use Up Section

    private var useUpSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space3) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use up before it expires")
                        .appTextStyle(.heading3)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                    Text("\(useUpSoonRecipes.count) recipe\(useUpSoonRecipes.count == 1 ? "" : "s") for ingredients going bad soon")
                        .font(.custom("Satoshi Variable", size: 12))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
                Spacer()
                Text("See all")
                    .font(.custom("Satoshi Variable", size: 13).weight(.medium))
                    .foregroundStyle(DS.ColorToken.accent)
            }
            .padding(.horizontal, DS.Spacing.space5)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.space3) {
                    ForEach(useUpSoonRecipes.prefix(10)) { recipe in
                        Button { selectedRecipe = recipe } label: {
                            RecipeCard(recipe: recipe).frame(width: 185)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.space5)
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
        VStack(alignment: .leading, spacing: DS.Spacing.space3) {
            HStack(spacing: DS.Spacing.space2) {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(DS.ColorToken.primary)
                Text(category.title)
                    .appTextStyle(.heading3)
                    .foregroundStyle(DS.ColorToken.textPrimary)
                Spacer()
                if category.recipes.count > 5 {
                    Button { navigateToCategory = category } label: {
                        Text("See More")
                            .font(.custom("Satoshi Variable", size: 13).weight(.medium))
                            .foregroundStyle(DS.ColorToken.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.space5)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DS.Spacing.space3) {
                    ForEach(category.recipes.prefix(5)) { recipe in
                        Button { selectedRecipe = recipe } label: {
                            RecipeCard(recipe: recipe).frame(width: 185)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.space5)
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

    private let gridColumns = [
        GridItem(.flexible(), spacing: DS.Spacing.space3),
        GridItem(.flexible(), spacing: DS.Spacing.space3)
    ]

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

    // MARK: - Grid View (Your Recipes / Saved)

    private func recipeGrid(recipes: [Recipe], emptyMessage: String) -> some View {
        Group {
            if recipes.isEmpty {
                Spacer(minLength: DS.Spacing.space8)
                Text(emptyMessage)
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: gridColumns, spacing: DS.Spacing.space3) {
                        ForEach(recipes) { recipe in
                            Button {
                                selectedRecipe = recipe
                            } label: {
                                RecipeCard(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.space5)
                    .padding(.bottom, DS.Spacing.space24)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [DS.ColorToken.bgPrimary, DS.ColorToken.bgPrimary.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 48)
                    .allowsHitTesting(false)
                }
            }
        }
    }

}

// MARK: - Recipe Preview Sheet

private struct RecipePreviewSheet: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    let onViewFull: () -> Void

    private var pantryMatchCount: Int {
        let pantryNames = Set(pantryStore.ingredients.map { $0.name.lowercased() })
        return recipe.ingredientsUsed.filter { pantryNames.contains($0.name.lowercased()) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(DS.ColorToken.borderDefault)
                    .frame(width: 36, height: 5)
                    .padding(.top, DS.Spacing.space3)
                    .padding(.bottom, DS.Spacing.space4)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.space6) {
                        // Recipe image
                        CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: true)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))

                        // Title
                        Text(recipe.title)
                            .appTextStyle(.heading2)
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        // Summary
                        Text(recipe.summary)
                            .appTextStyle(.body)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        // Meta info
                        HStack(spacing: DS.Spacing.space4) {
                            Label("\(recipe.timeMinutes) min", systemImage: "clock")
                            Label("\(recipe.servings) servings", systemImage: "person.2")
                        }
                        .appTextStyle(.bodySM)
                        .foregroundStyle(DS.ColorToken.textSecondary)

                        // Dietary pills
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

                        if recipe.rating > 0 {
                            HStack(spacing: DS.Spacing.space2) {
                                StarRatingView(rating: recipe.rating, size: 14)
                                Text(recipe.rating.truncatingRemainder(dividingBy: 1) == 0
                                     ? String(format: "%.0f", recipe.rating)
                                     : String(format: "%.1f", recipe.rating))
                                    .appTextStyle(.bodySM)
                                    .foregroundStyle(DS.ColorToken.textSecondary)
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

                        // Macros summary
                        HStack(spacing: DS.Spacing.space3) {
                            macroPill("Cal", value: "\(recipe.macros.calories)")
                            macroPill("Protein", value: "\(recipe.macros.proteinG)g")
                            macroPill("Carbs", value: "\(recipe.macros.carbsG)g")
                            macroPill("Fat", value: "\(recipe.macros.fatG)g")
                        }

                        // Ingredients preview
                        if !recipe.ingredientsUsed.isEmpty {
                            VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                                Text("Ingredients")
                                    .appTextStyle(.heading3)
                                    .foregroundStyle(DS.ColorToken.textPrimary)

                                ForEach(Array(recipe.ingredientsUsed.prefix(5))) { ingredient in
                                    Text("\u{2022} \(ingredient.displayText)")
                                        .appTextStyle(.bodySM)
                                        .foregroundStyle(DS.ColorToken.textSecondary)
                                }

                                if recipe.ingredientsUsed.count > 5 {
                                    Text("+\(recipe.ingredientsUsed.count - 5) more")
                                        .appTextStyle(.bodySM)
                                        .foregroundStyle(DS.ColorToken.textTertiary)
                                }

                                if pantryMatchCount > 0 {
                                    HStack(spacing: DS.Spacing.space1) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(DS.ColorToken.success)
                                        Text("You have \(pantryMatchCount) of \(recipe.ingredientsUsed.count) ingredients")
                                            .appTextStyle(.bodySM)
                                            .foregroundStyle(DS.ColorToken.success)
                                    }
                                    .padding(.top, DS.Spacing.space1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.space5)
                }

                // View Full Recipe button
                Button(action: onViewFull) {
                    Text("View Full Recipe")
                        .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(DS.ColorToken.primary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DS.Spacing.space5)
                .padding(.top, DS.Spacing.space3)
                .padding(.bottom, DS.Spacing.space4)
            }
        .background(DS.ColorToken.bgPrimary)
    }

    private func macroPill(_ label: String, value: String) -> some View {
        VStack(spacing: DS.Spacing.space1) {
            Text(value)
                .appTextStyle(.bodySM)
                .foregroundStyle(DS.ColorToken.textPrimary)
            Text(label)
                .appTextStyle(.caption)
                .foregroundStyle(DS.ColorToken.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.space2)
        .background(DS.ColorToken.bgSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
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
                .fill(DS.ColorToken.borderDefault)
                .frame(width: 36, height: 5)
                .padding(.top, DS.Spacing.space3)
                .padding(.bottom, DS.Spacing.space4)

            // Header
            HStack {
                Text("Filters")
                    .appTextStyle(.heading2)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()

                if hasActiveFilters {
                    Button("Reset") {
                        selectedCuisine = nil
                        maxPrepTime = nil
                        selectedIngredients = []
                        selectedDietaryFilters = []
                    }
                    .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                    .foregroundStyle(DS.ColorToken.error)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.bottom, DS.Spacing.space6)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.space6) {
                    // Ingredients filter
                    if !pantryIngredients.isEmpty {
                        VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                            Text("Ingredients")
                                .appTextStyle(.heading3)
                                .foregroundStyle(DS.ColorToken.textPrimary)

                            Text("Show recipes that use these pantry items")
                                .appTextStyle(.bodySM)
                                .foregroundStyle(DS.ColorToken.textTertiary)

                            FlowLayout(spacing: DS.Spacing.space2) {
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
                    VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                        Text("Cuisine")
                            .appTextStyle(.heading3)
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        FlowLayout(spacing: DS.Spacing.space2) {
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
                    VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                        Text("Max Prep Time")
                            .appTextStyle(.heading3)
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        FlowLayout(spacing: DS.Spacing.space2) {
                            ForEach(Self.prepTimeOptions, id: \.label) { option in
                                filterChip(option.label, isSelected: maxPrepTime == option.value) {
                                    maxPrepTime = option.value
                                }
                            }
                        }
                    }

                    // Dietary filter
                    VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                        Text("Dietary")
                            .appTextStyle(.heading3)
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        FlowLayout(spacing: DS.Spacing.space2) {
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
                .padding(.horizontal, DS.Spacing.space5)
            }

            // Done button
            Button { dismiss() } label: {
                Text("Show Results")
                    .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(DS.ColorToken.primary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space4)
        }
        .background(DS.ColorToken.bgPrimary)
    }

    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                .foregroundStyle(isSelected ? .white : DS.ColorToken.textSecondary)
                .padding(.horizontal, DS.Spacing.space5)
                .frame(height: 36)
                .background(isSelected ? DS.ColorToken.accent : DS.ColorToken.bgSecondary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : DS.ColorToken.borderDefault, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
