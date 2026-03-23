import SwiftUI

#Preview("Recipes") {
    PreviewContainer {
        NavigationStack {
            RecipesView()
        }
    }
}

private enum RecipeTab: String, CaseIterable {
    case community = "Community"
    case yours = "Your Recipes"
    case saved = "Saved"
}

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

private struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .aspectRatio(4/3, contentMode: .fit)
                .overlay {
                    if recipe.isAIGenerated && recipe.imageData == nil && recipe.imagePath == nil {
                        LinearGradient(
                            colors: [DS.ColorToken.primary, DS.ColorToken.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: true)
                    }
                }
                .clipped()
                .overlay(alignment: .topLeading) {
                    if recipe.isAIGenerated {
                        AIGeneratedBadge()
                            .padding(8)
                    }
                }
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
}

struct RecipesView: View {
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var pantryStore: PantryStore

    @State private var selectedTab: RecipeTab = .community
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var showingShareSheet = false
    @State private var selectedRecipe: Recipe?
    @State private var navigateToRecipe: Recipe?
    @State private var showingFilterSheet = false
    @State private var selectedCuisine: Cuisine?
    @State private var maxPrepTime: Int?
    @State private var selectedIngredients: Set<String> = []
    @State private var cachedCommunityCategories: [RecipeCategory] = []
    @State private var navigateToCategory: RecipeCategory?

    private var hasActiveFilters: Bool {
        selectedCuisine != nil || maxPrepTime != nil || !selectedIngredients.isEmpty
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

        return result
    }

    private var filteredCommunityRecipes: [Recipe] {
        applyFilters(savedRecipesStore.communityRecipes)
    }

    private var filteredYourRecipes: [Recipe] {
        applyFilters(savedRecipesStore.sharedRecipes)
    }

    private var filteredSavedRecipes: [Recipe] {
        applyFilters(savedRecipesStore.savedRecipes)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            VStack(spacing: DS.Spacing.space3) {
                // Tab pills
                tabRow

                // Search bar
                searchBar
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space4)

            // Content
            Group {
                switch selectedTab {
                case .community:
                    categorizedRecipeList(recipes: filteredCommunityRecipes)
                case .yours:
                    recipeGrid(
                        recipes: filteredYourRecipes,
                        emptyMessage: "You haven't shared any recipes yet."
                    )
                case .saved:
                    recipeGrid(
                        recipes: filteredSavedRecipes,
                        emptyMessage: "No saved recipes yet. Save one from the Generate tab."
                    )
                }
            }
            .padding(.top, DS.Spacing.space3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(DS.ColorToken.bgPrimary)
        }
        .background(DS.ColorToken.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingShareSheet) {
            ShareRecipeSheet()
        }
        .sheet(isPresented: $showingFilterSheet) {
            RecipeFilterSheet(
                selectedCuisine: $selectedCuisine,
                maxPrepTime: $maxPrepTime,
                selectedIngredients: $selectedIngredients,
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
        HStack {
            Text("Today is \(Date.now, format: .dateTime.month(.wide).day())")
                .font(.custom("Satoshi Variable", size: 22).weight(.semibold))
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()

            Button {
                showingShareSheet = true
            } label: {
                HStack(spacing: DS.Spacing.space1) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Share Recipe")
                        .font(.custom("Satoshi Variable", size: 14).weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.space3)
                .frame(height: 34)
                .background(DS.ColorToken.primary)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.top, DS.Spacing.space2)
        .padding(.bottom, DS.Spacing.space4)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
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
    }

    // MARK: - Tab Row

    private var tabRow: some View {
        HStack(spacing: DS.Spacing.space2) {
            ForEach(RecipeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(DS.Motion.easeDefault) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                        .foregroundStyle(
                            selectedTab == tab ? .white : DS.ColorToken.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(
                            selectedTab == tab
                                ? DS.ColorToken.midnight
                                : DS.ColorToken.bgSecondary
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    selectedTab == tab
                                        ? Color.clear
                                        : DS.ColorToken.borderDefault,
                                    lineWidth: 1
                                )
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                showingFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(hasActiveFilters ? DS.ColorToken.primary : DS.ColorToken.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(DS.ColorToken.bgSecondary)
                        .overlay(
                            Capsule()
                                .stroke(hasActiveFilters ? DS.ColorToken.primary : DS.ColorToken.borderDefault, lineWidth: 1)
                        )
                        .clipShape(Capsule())

                    if hasActiveFilters {
                        Circle()
                            .fill(DS.ColorToken.primary)
                            .frame(width: 8, height: 8)
                            .offset(x: -2, y: 2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Recipe List

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

    private func categorizedRecipeList(recipes: [Recipe]) -> some View {
        Group {
            if recipes.isEmpty {
                Spacer(minLength: DS.Spacing.space8)
                Text("No community recipes yet. Be the first to share!")
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: DS.Spacing.space6) {
                        ForEach(cachedCommunityCategories) { category in
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
                                        Button {
                                            navigateToCategory = category
                                        } label: {
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
                                            Button {
                                                selectedRecipe = recipe
                                            } label: {
                                                RecipeCard(recipe: recipe)
                                                    .frame(width: 185)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, DS.Spacing.space5)
                                }
                            }
                        }
                    }
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
        ZStack(alignment: .topTrailing) {
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

            // Dismiss button - top right
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(DS.ColorToken.textTertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, DS.Spacing.space3)
            .padding(.trailing, DS.Spacing.space5)
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
    let allRecipes: [Recipe]
    let pantryIngredients: [Ingredient]

    private var sortedPantryNames: [String] {
        pantryIngredients.map(\.name).sorted()
    }

    private var hasActiveFilters: Bool {
        selectedCuisine != nil || maxPrepTime != nil || !selectedIngredients.isEmpty
    }

    private static let prepTimeOptions: [(label: String, value: Int?)] = [
        ("Any", nil),
        ("15 min", 15),
        ("30 min", 30),
        ("45 min", 45),
        ("60 min", 60)
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
                .background(isSelected ? DS.ColorToken.midnight : DS.ColorToken.bgSecondary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : DS.ColorToken.borderDefault, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
