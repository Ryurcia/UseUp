import Foundation
import Supabase
import UIKit

// MARK: - DTOs

/// Decodable row for the `recipe_ingredients` table.
private struct RecipeIngredientRow: Decodable {
    let id: UUID
    let recipeId: UUID
    let kind: String
    let name: String
    let quantity: String

    enum CodingKeys: String, CodingKey {
        case id
        case recipeId = "recipe_id"
        case kind, name, quantity
    }
}

/// Decodable row for the `source_links` table.
private struct SourceLinkRow: Decodable {
    let id: UUID
    let recipeId: UUID
    let title: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case id
        case recipeId = "recipe_id"
        case title, url
    }
}

/// Combined row for nested select: `*, recipe_ingredients(*), source_links(*)`.
private struct RecipeRowWithRelations: Decodable {
    let id: UUID
    let createdBy: UUID
    let title: String
    let summary: String
    let timeMinutes: Int
    let servings: Int
    let steps: [String]
    let cuisine: String
    let isUserShared: Bool
    let isAIGenerated: Bool
    let imagePath: String?
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    let avgRating: Double
    let ratingCount: Int
    let dietType: String?
    let dietaryRestrictions: [String]?
    let tags: [String]?
    let recipeIngredients: [RecipeIngredientRow]
    let sourceLinks: [SourceLinkRow]

    enum CodingKeys: String, CodingKey {
        case id
        case createdBy = "created_by"
        case title, summary
        case timeMinutes = "time_minutes"
        case servings, steps, cuisine
        case isUserShared = "is_user_shared"
        case isAIGenerated = "is_ai_generated"
        case imagePath = "image_path"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case avgRating = "avg_rating"
        case ratingCount = "rating_count"
        case dietType = "diet_type"
        case dietaryRestrictions = "dietary_restrictions"
        case tags
        case recipeIngredients = "recipe_ingredients"
        case sourceLinks = "source_links"
    }

    func toRecipe(nicknameMap: [String: String] = [:]) -> Recipe {
        let used = recipeIngredients
            .filter { $0.kind == "used" }
            .map { RecipeIngredient(id: $0.id, name: $0.name, quantity: $0.quantity) }
        let missing = recipeIngredients
            .filter { $0.kind == "missing" }
            .map { RecipeIngredient(id: $0.id, name: $0.name, quantity: $0.quantity) }
        let sources = sourceLinks.compactMap { row -> SourceLink? in
            guard let url = URL(string: row.url) else { return nil }
            return SourceLink(id: row.id, title: row.title, url: url)
        }
        let createdByIdString = createdBy.uuidString
        let displayName = nicknameMap[createdByIdString] ?? nicknameMap[createdByIdString.lowercased()]

        return Recipe(
            id: id,
            title: title,
            summary: summary,
            timeMinutes: timeMinutes,
            servings: servings,
            ingredientsUsed: used,
            missingIngredients: missing,
            steps: steps,
            macros: Macros(calories: calories, proteinG: proteinG, carbsG: carbsG, fatG: fatG),
            sources: sources,
            isUserShared: isUserShared,
            imagePath: imagePath,
            cuisine: Cuisine(databaseValue: cuisine) ?? .other,
            createdBy: createdByIdString,
            createdByName: displayName,
            rating: avgRating,
            dietType: dietType ?? "any",
            dietaryRestrictions: dietaryRestrictions ?? [],
            tags: tags ?? [],
            isAIGenerated: isAIGenerated
        )
    }
}

/// Encodable payload for inserting into `recipes`.
private struct RecipeInsert: Encodable {
    let createdBy: UUID
    let title: String
    let summary: String
    let timeMinutes: Int
    let servings: Int
    let steps: [String]
    let cuisine: String
    let isUserShared: Bool
    let imagePath: String?
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    let dietType: String
    let dietaryRestrictions: [String]
    let tags: [String]
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case createdBy = "created_by"
        case title, summary
        case timeMinutes = "time_minutes"
        case servings, steps, cuisine
        case isUserShared = "is_user_shared"
        case imagePath = "image_path"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case dietType = "diet_type"
        case dietaryRestrictions = "dietary_restrictions"
        case tags
        case isPublic = "public"
    }
}

/// Encodable payload for inserting into `recipe_ingredients`.
private struct RecipeIngredientInsert: Encodable {
    let recipeId: UUID
    let kind: String
    let name: String
    let quantity: String

    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case kind, name, quantity
    }
}

/// Encodable payload for inserting into `source_links`.
private struct SourceLinkInsert: Encodable {
    let recipeId: UUID
    let title: String
    let url: String

    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case title, url
    }
}

/// Decodable row for `saved_recipes` join table.
private struct SavedRecipeRow: Decodable {
    let userId: UUID
    let recipeId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case recipeId = "recipe_id"
    }
}

/// Encodable payload for inserting into `saved_recipes`.
private struct SavedRecipeInsert: Encodable {
    let userId: UUID
    let recipeId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case recipeId = "recipe_id"
    }
}

/// Decodable row for `collections`.
private struct CollectionRow: Decodable {
    let id: UUID
    let name: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
    }

    func toCollection() -> RecipeCollection { RecipeCollection(id: id, name: name, createdAt: createdAt) }
}

/// Encodable payload for inserting into `collections`. `user_id` is deliberately omitted —
/// `Migrations/034_recreate_collections.sql` defaults that column to `auth.uid()`, so Postgres
/// fills it in from the request's own JWT rather than trusting a client-supplied value.
private struct CollectionInsert: Encodable {
    let name: String
}

/// Decodable row for `collection_recipes`.
private struct CollectionRecipeRow: Decodable {
    let collectionId: UUID
    let recipeId: UUID

    enum CodingKeys: String, CodingKey {
        case collectionId = "collection_id"
        case recipeId = "recipe_id"
    }
}

/// Encodable payload for inserting into `collection_recipes`. `user_id` is omitted for the same
/// reason as `CollectionInsert` — it defaults to `auth.uid()` on the table.
private struct CollectionRecipeInsert: Encodable {
    let collectionId: UUID
    let recipeId: UUID

    enum CodingKeys: String, CodingKey {
        case collectionId = "collection_id"
        case recipeId = "recipe_id"
    }
}

/// Encodable payload for inserting an AI-generated recipe, using its existing UUID as PK.
private struct AIRecipeInsert: Encodable {
    let id: UUID
    let createdBy: UUID
    let title: String
    let summary: String
    let timeMinutes: Int
    let servings: Int
    let steps: [String]
    let cuisine: String
    let isUserShared: Bool
    let isPublic: Bool
    let isAIGenerated: Bool
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    let dietType: String
    let dietaryRestrictions: [String]
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case createdBy = "created_by"
        case title, summary
        case timeMinutes = "time_minutes"
        case servings, steps, cuisine
        case isUserShared = "is_user_shared"
        case isPublic = "public"
        case isAIGenerated = "is_ai_generated"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
        case dietType = "diet_type"
        case dietaryRestrictions = "dietary_restrictions"
        case tags
    }

    init(recipe: Recipe, createdBy: UUID) {
        id = recipe.id
        self.createdBy = createdBy
        title = recipe.title
        summary = recipe.summary
        timeMinutes = recipe.timeMinutes
        servings = recipe.servings
        steps = recipe.steps
        cuisine = recipe.cuisine.databaseValue
        isUserShared = false
        isPublic = false
        isAIGenerated = true
        calories = recipe.macros.calories
        proteinG = recipe.macros.proteinG
        carbsG = recipe.macros.carbsG
        fatG = recipe.macros.fatG
        dietType = recipe.dietType
        dietaryRestrictions = recipe.dietaryRestrictions
        tags = recipe.tags
    }
}

/// Minimal decodable used only to extract the ID after a recipe INSERT.
private struct InsertedID: Decodable { let id: UUID }

/// Decodable row for fetching the current user's ratings.
private struct UserRatingRow: Decodable {
    let recipeId: UUID
    let rating: Double
    let review: String?

    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case rating, review
    }
}

/// Decodable row for community review ratings.
private struct CommunityReviewRow: Decodable {
    let userId: UUID
    let rating: Double
    let review: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case rating, review
        case createdAt = "created_at"
    }
}

/// Decodable row for reviewer profile info.
private struct ReviewerProfileRow: Decodable {
    let id: UUID
    let nickname: String?
    let avatarPath: String?

    enum CodingKeys: String, CodingKey {
        case id, nickname
        case avatarPath = "avatar_path"
    }
}

/// Encodable payload for upserting into `recipe_ratings`.
private struct RatingInsert: Encodable {
    let userId: UUID
    let recipeId: UUID
    let rating: Double
    let review: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case recipeId = "recipe_id"
        case rating, review
    }
}

// MARK: - Store

@MainActor
final class SavedRecipesStore: ObservableObject {
    static weak var shared: SavedRecipesStore?

    @Published private(set) var savedRecipes: [Recipe]
    @Published private(set) var sharedRecipes: [Recipe]
    @Published private(set) var communityRecipes: [Recipe] = []
    @Published private(set) var communityReviews: [UUID: [CommunityReview]] = [:]
    @Published private(set) var collections: [RecipeCollection] = []
    @Published private(set) var savedRecipeCollections: [UUID: Set<UUID>] = [:]  // recipeId -> Set<collectionId>
    /// Recipe rows for everything referenced by `collection_recipes`, fetched alongside the
    /// membership map. `recipes(in:)` falls back to this so a collection's contents resolve from
    /// the collection itself — without it, a perfectly valid membership row renders as nothing
    /// whenever the recipe happens not to be loaded in `savedRecipes`/`communityRecipes`/`sharedRecipes`.
    @Published private(set) var collectionRecipeCache: [UUID: Recipe] = [:]
    @Published private(set) var isLoading = false
    @Published var error: String?

    /// Community feed pagination — `communityRecipes` holds whatever pages have loaded so far.
    @Published private(set) var hasMoreCommunityRecipes = true
    @Published private(set) var isLoadingMoreCommunityRecipes = false

    /// Server-side search results — separate from `communityRecipes`, its own pagination.
    @Published private(set) var searchResults: [Recipe] = []
    @Published private(set) var isSearching = false
    @Published private(set) var isLoadingMoreSearchResults = false
    @Published private(set) var hasMoreSearchResults = true

    /// Discovery sections for the default (no-filter) Recipes tab browsing state — fetched
    /// server-side (via `fetchCategoryRecipes`/`get_cuisine_counts`) so a cuisine/category
    /// shows up as soon as it has content, instead of waiting for enough of it to
    /// coincidentally appear in the paginated `communityRecipes` feed.
    @Published private(set) var discoveryGeneralRecipes: [String: [Recipe]] = [:]
    @Published private(set) var discoveryCuisineRecipes: [Cuisine: [Recipe]] = [:]
    @Published private(set) var discoveryCuisineOrder: [Cuisine] = []
    @Published private(set) var isLoadingDiscoverySections = false

    var userId: UUID? {
        didSet {
            guard oldValue != userId else { return }
            if oldValue != nil {
                savedRecipes = []
                sharedRecipes = []
                communityRecipes = []
                collections = []
                savedRecipeCollections = [:]
                collectionRecipeCache = [:]
            }
            fetchGeneration = UUID()
            fetchTask?.cancel()
            fetchTask = nil
            lastFetchedAt = nil
            isLoading = false

            discoveryTask?.cancel()
            discoveryTask = nil
            discoverySectionsFetchedAt = nil
            discoveryGeneralRecipes = [:]
            discoveryCuisineRecipes = [:]
            discoveryCuisineOrder = []
            isLoadingDiscoverySections = false
        }
    }
    private var fetchGeneration = UUID()
    private var fetchTask: Task<Void, Never>?

    var currentUserNickname: String?
    private var lastFetchedAt: Date?
    private var discoveryTask: Task<Void, Never>?
    private var discoverySectionsFetchedAt: Date?
    private var reviewsFetchedAt: [UUID: Date] = [:]
    private let client = SupabaseManager.client
    private let recipePageSize = 20

    init(
        savedRecipes: [Recipe] = [],
        sharedRecipes: [Recipe] = [],
        communityRecipes: [Recipe] = []
    ) {
        self.savedRecipes = savedRecipes
        self.sharedRecipes = sharedRecipes
        self.communityRecipes = communityRecipes
        SavedRecipesStore.shared = self
    }

    private func getUserId() -> UUID? { userId }

    /// Applies a local mutation immediately (optimistic update), then runs `persist` (the network
    /// call plus any post-success work). If `persist` throws, the local mutation is rolled back and
    /// the error surfaced via `self.error`.
    private func performOptimistic(
        apply: () -> Void,
        rollback: @escaping () -> Void,
        persist: @escaping () async throws -> Void
    ) {
        apply()
        Task {
            do {
                try await persist()
            } catch {
                rollback()
                self.error = error.localizedDescription
            }
        }
    }

    func clearForSignOut() {
        userId = nil
        currentUserNickname = nil
        savedRecipes = []
        sharedRecipes = []
        communityRecipes = []
        communityReviews = [:]
        collections = []
        savedRecipeCollections = [:]
        collectionRecipeCache = [:]
        lastFetchedAt = nil
        error = nil
    }

    // MARK: - Fetch

    /// Decodable row for looking up nicknames from `profiles`.
    private struct NicknameRow: Decodable {
        let id: UUID
        let nickname: String?
    }

    /// Minimal row for `returning`-style upserts where only "was anything actually inserted?" matters.
    private struct RecipeIDRow: Decodable {
        let id: UUID
    }

    /// Fetch nicknames for a set of user UUIDs, returning a map of UUID string → nickname.
    private func fetchNicknames(for userIds: Set<UUID>) async -> [String: String] {
        guard !userIds.isEmpty else { return [:] }
        do {
            let rows: [NicknameRow] = try await client
                .from("profiles")
                .select("id, nickname")
                .in("id", values: userIds.map { $0.uuidString })
                .execute()
                .value
            var map: [String: String] = [:]
            for row in rows {
                if let nickname = row.nickname {
                    map[row.id.uuidString] = nickname
                }
            }
            return map
        } catch {
            return [:]
        }
    }

    /// Fetch the current user's ratings for a set of recipe IDs.
    private func fetchUserRatings(for recipeIds: [UUID], userId: UUID) async -> [UUID: (rating: Double, review: String?)] {
        guard !recipeIds.isEmpty else { return [:] }
        do {
            let rows: [UserRatingRow] = try await client
                .from("recipe_ratings")
                .select("recipe_id, rating, review")
                .eq("user_id", value: userId.uuidString)
                .in("recipe_id", values: recipeIds.map { $0.uuidString })
                .execute()
                .value
            var map: [UUID: (rating: Double, review: String?)] = [:]
            for row in rows {
                map[row.recipeId] = (rating: row.rating, review: row.review)
            }
            return map
        } catch {
            return [:]
        }
    }

    /// Hydrates raw rows into `[Recipe]` (creator nicknames + the current user's own rating/review
    /// merged in) — the per-batch equivalent of the nickname/rating logic inlined in `fetchRecipes()`,
    /// factored out so paginated fetches (a "load more" page, a search page) can reuse it without
    /// re-fetching or re-merging the whole existing `communityRecipes`/`savedRecipes` arrays.
    private func hydrateRecipes(from rows: [RecipeRowWithRelations]) async -> [Recipe] {
        let nicknameMap = await fetchNicknames(for: Set(rows.map { $0.createdBy }))
        var recipes = rows.map { $0.toRecipe(nicknameMap: nicknameMap) }
        guard let userId = getUserId() else { return recipes }
        let ratings = await fetchUserRatings(for: recipes.map(\.id), userId: userId)
        for i in recipes.indices {
            if let rating = ratings[recipes[i].id] {
                recipes[i].userRating = rating.rating
                recipes[i].review = rating.review
            }
        }
        return recipes
    }

    func fetchRecipes() async {
        guard let userId else { return }
        if let fetchTask { await fetchTask.value; return }
        if let last = lastFetchedAt, Date().timeIntervalSince(last) < 60 { return }
        let generation = fetchGeneration
        let task = Task { await self.loadInitialData(userId: userId, generation: generation) }
        fetchTask = task
        await task.value
        if fetchGeneration == generation { fetchTask = nil }
    }

    private func loadInitialData(userId: UUID, generation: UUID) async {
        guard fetchGeneration == generation, !Task.isCancelled else { return }
        isLoading = true
        error = nil
        defer { if fetchGeneration == generation { isLoading = false } }

        do {
            // Fetch community recipes and bookmark IDs in parallel
            async let communityRowsTask: [RecipeRowWithRelations] = client
                .from("recipes")
                .select("*, recipe_ingredients(*), source_links(*)")
                .eq("is_user_shared", value: true)
                .order("created_at", ascending: false)
                .range(from: 0, to: recipePageSize - 1)
                .execute()
                .value
            async let bookmarkRowsTask: [SavedRecipeRow] = client
                .from("saved_recipes")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            let (communityRows, bookmarkRows) = try await (communityRowsTask, bookmarkRowsTask)

            guard fetchGeneration == generation, !Task.isCancelled else { return }
            // Collections is a secondary feature layered on top of the recipe list. Fetch it
            // separately so a failure here (RLS hiccup, schema-cache lag, etc.) can't take down
            // the primary recipe list, which is load-bearing for the whole Recipes screen. A miss
            // here doesn't stay missed, though — `fetchCollections()` runs this same fetch,
            // unthrottled, every time the Collections tab or the save-to-collection picker
            // appears, so it self-heals the next time the user actually looks at collections.
            do {
                let (fetchedCollections, membership, memberRecipes) = try await fetchCollectionsAndMembership(userId: userId)
                guard fetchGeneration == generation, !Task.isCancelled else { return }
                collections = fetchedCollections
                savedRecipeCollections = membership
                collectionRecipeCache = memberRecipes
            } catch {
                // Self-heals: `fetchCollections()` runs this same fetch again the next time
                // the Collections tab or save-to-collection picker appears.
            }

            // Fetch saved recipes by ID
            let savedRecipeIds = bookmarkRows.map { $0.recipeId }
            var savedRows: [RecipeRowWithRelations] = []
            if !savedRecipeIds.isEmpty {
                savedRows = try await client
                    .from("recipes")
                    .select("*, recipe_ingredients(*), source_links(*)")
                    .in("id", values: savedRecipeIds.map { $0.uuidString })
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            }

            // Fetch nicknames for all creators in one round-trip
            let allCreatorIds = Set(communityRows.map { $0.createdBy })
                .union(Set(savedRows.map { $0.createdBy }))
            let nicknameMap = await fetchNicknames(for: allCreatorIds)

            guard fetchGeneration == generation, !Task.isCancelled else { return }
            communityRecipes = communityRows.map { $0.toRecipe(nicknameMap: nicknameMap) }
            hasMoreCommunityRecipes = communityRows.count == recipePageSize
            sharedRecipes = communityRecipes.filter { $0.createdBy == userId.uuidString }
            savedRecipes = savedRows.map { $0.toRecipe(nicknameMap: nicknameMap) }

            // Refresh pre-computed recipe suggestions for expiring ingredients
            if let pantryStore = PantryStore.shared {
                let expiring = pantryStore.ingredients.filter {
                    guard let d = $0.daysUntilExpiration else { return false }
                    return d >= 0 && d <= 4
                }
                SuggestedRecipeCache.shared.refresh(
                    expiringIngredients: expiring,
                    allRecipes: communityRecipes + savedRecipes
                )
            }

            // Fetch user's own ratings for all loaded recipes
            let allRecipeIds = Array(Set(communityRecipes.map(\.id) + savedRecipes.map(\.id)))
            let userRatings = await fetchUserRatings(for: allRecipeIds, userId: userId)

            guard fetchGeneration == generation, !Task.isCancelled else { return }
            // Merge user ratings onto recipe arrays.
            // Build id→index maps once to avoid O(ratings × recipes) firstIndex scans.
            let communityIndex = Dictionary(communityRecipes.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
            let sharedIndex = Dictionary(sharedRecipes.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })
            let savedIndex = Dictionary(savedRecipes.enumerated().map { ($0.element.id, $0.offset) }, uniquingKeysWith: { first, _ in first })

            for (recipeId, ratingData) in userRatings {
                if let idx = communityIndex[recipeId] {
                    communityRecipes[idx].userRating = ratingData.rating
                    communityRecipes[idx].review = ratingData.review
                }
                if let idx = sharedIndex[recipeId] {
                    sharedRecipes[idx].userRating = ratingData.rating
                    sharedRecipes[idx].review = ratingData.review
                }
                if let idx = savedIndex[recipeId] {
                    savedRecipes[idx].userRating = ratingData.rating
                    savedRecipes[idx].review = ratingData.review
                }
            }

            lastFetchedAt = Date()
        } catch {
            guard fetchGeneration == generation, !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }

    }

    /// Appends the next page of the community feed onto `communityRecipes`, same filter/sort as
    /// `fetchRecipes()`'s initial page. Distinct `isLoadingMoreCommunityRecipes` flag so the UI can
    /// tell "loading more" apart from the initial `isLoading` spinner.
    func fetchMoreCommunityRecipes() async {
        guard !isLoadingMoreCommunityRecipes, hasMoreCommunityRecipes else { return }
        isLoadingMoreCommunityRecipes = true
        defer { isLoadingMoreCommunityRecipes = false }

        do {
            let offset = communityRecipes.count
            let rows: [RecipeRowWithRelations] = try await client
                .from("recipes")
                .select("*, recipe_ingredients(*), source_links(*)")
                .eq("is_user_shared", value: true)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + recipePageSize - 1)
                .execute()
                .value

            communityRecipes.append(contentsOf: await hydrateRecipes(from: rows))
            hasMoreCommunityRecipes = rows.count == recipePageSize
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// First page of server-side search results, ranked/typo-tolerant via the `search_vector`
    /// generated tsvector column (`websearch_to_tsquery` semantics) — replaces `searchResults`
    /// entirely, unlike `fetchMoreSearchResults` which appends.
    func searchRecipes(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            hasMoreSearchResults = true
            return
        }
        isSearching = true
        searchResults = []
        defer { isSearching = false }

        do {
            let rows: [RecipeRowWithRelations] = try await client
                .from("recipes")
                .select("*, recipe_ingredients(*), source_links(*)")
                .eq("is_user_shared", value: true)
                .textSearch("search_vector", query: trimmed, config: "english", type: .websearch)
                .order("created_at", ascending: false)
                .range(from: 0, to: recipePageSize - 1)
                .execute()
                .value

            searchResults = await hydrateRecipes(from: rows)
            hasMoreSearchResults = rows.count == recipePageSize
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Appends the next page of search results for the same query onto `searchResults`.
    func fetchMoreSearchResults(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoadingMoreSearchResults, hasMoreSearchResults else { return }
        isLoadingMoreSearchResults = true
        defer { isLoadingMoreSearchResults = false }

        do {
            let offset = searchResults.count
            let rows: [RecipeRowWithRelations] = try await client
                .from("recipes")
                .select("*, recipe_ingredients(*), source_links(*)")
                .eq("is_user_shared", value: true)
                .textSearch("search_vector", query: trimmed, config: "english", type: .websearch)
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + recipePageSize - 1)
                .execute()
                .value

            searchResults.append(contentsOf: await hydrateRecipes(from: rows))
            hasMoreSearchResults = rows.count == recipePageSize
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch Category Recipes (Paginated)

    enum CategoryFilter {
        case cuisine(Cuisine)
        case cuisineGroup(Set<Cuisine>)
        case lowCalorie(maxCalories: Int)
        case highProtein(minProteinG: Int)
        case quick(maxMinutes: Int)
        case tag(String)
        case tagGroup(Set<String>)

        /// In-memory equivalent of this filter's SQL translation in `fetchCategoryRecipes`
        /// — the single definition of "does this recipe belong to this category," reused
        /// by both the server-driven discovery fetch and `RecipesView.buildCategories`'s
        /// client-side fallback (when a filter/quick-filter is active) so the two paths
        /// can't drift apart the way `RecipesView`'s duplicated general-category list did.
        func matches(_ recipe: Recipe) -> Bool {
            switch self {
            case .cuisine(let cuisine): return recipe.cuisine == cuisine
            case .cuisineGroup(let cuisines): return cuisines.contains(recipe.cuisine)
            case .lowCalorie(let max): return recipe.macros.calories <= max
            case .highProtein(let min): return recipe.macros.proteinG >= min
            case .quick(let max): return recipe.timeMinutes <= max
            case .tag(let tag): return recipe.tags.contains(tag)
            case .tagGroup(let tags): return !tags.isDisjoint(with: Set(recipe.tags))
            }
        }
    }

    struct GeneralCategorySpec {
        let title: String
        let icon: String
        let filter: CategoryFilter
    }

    /// Single source of truth for the Recipes tab's "QUICK PICKS" general categories —
    /// used both to fetch them server-side (`fetchDiscoverySections`) and to derive them
    /// client-side (`RecipesView.buildCategories`) when a filter is active.
    static let generalCategorySpecs: [GeneralCategorySpec] = [
        GeneralCategorySpec(title: "Low Calorie", icon: "flame", filter: .lowCalorie(maxCalories: 200)),
        GeneralCategorySpec(title: "High Protein", icon: "bolt.fill", filter: .highProtein(minProteinG: 30)),
        GeneralCategorySpec(title: "Quick & Easy", icon: "clock", filter: .quick(maxMinutes: 15)),
        GeneralCategorySpec(title: "Comfort Food", icon: "heart.fill", filter: .tag("comfort-food")),
        GeneralCategorySpec(title: "Weeknight Dinners", icon: "calendar", filter: .tag("weeknight")),
        GeneralCategorySpec(title: "Spicy", icon: "flame.fill", filter: .tag("spicy")),
        GeneralCategorySpec(title: "Soups & Stews", icon: "cup.and.saucer.fill", filter: .tagGroup(["soup", "stew"])),
        GeneralCategorySpec(title: "Budget-Friendly", icon: "dollarsign.circle", filter: .tag("budget-friendly"))
    ]

    func fetchCategoryRecipes(filter: CategoryFilter, limit: Int = 30, offset: Int = 0) async -> [Recipe] {
        do {
            let rows = try await fetchCategoryRows(filter: filter, limit: limit, offset: offset)
            return await hydrateRecipes(from: rows)
        } catch { return [] }
    }

    private func fetchCategoryRows(filter: CategoryFilter, limit: Int, offset: Int = 0) async throws -> [RecipeRowWithRelations] {
        var query = client
            .from("recipes")
            .select("*, recipe_ingredients(*), source_links(*)")
            .eq("is_user_shared", value: true)

        switch filter {
        case .cuisine(let cuisine):
            query = query.eq("cuisine", value: cuisine.databaseValue)
        case .cuisineGroup(let cuisines):
            query = query.in("cuisine", values: cuisines.map { $0.databaseValue })
        case .lowCalorie(let max):
            query = query.lte("calories", value: max)
        case .highProtein(let min):
            query = query.gte("protein_g", value: min)
        case .quick(let max):
            query = query.lte("time_minutes", value: max)
        case .tag(let tag):
            query = query.contains("tags", value: [tag])
        case .tagGroup(let tags):
            query = query.overlaps("tags", value: Array(tags))
        }

        return try await query
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

    }

    // MARK: - Discovery Sections (server-driven cuisine/category rows)

    private struct CuisineCountRow: Decodable {
        let cuisine: String
        let cnt: Int
    }

    /// Recipe counts per cuisine across the whole shared feed (not just what's paginated
    /// in locally), via the `get_cuisine_counts()` SQL function — one cheap aggregate query
    /// instead of scanning `communityRecipes`.
    private func fetchCuisineCounts() async -> [Cuisine: Int] {
        do {
            let rows: [CuisineCountRow] = try await client
                .rpc("get_cuisine_counts")
                .execute()
                .value
            var result: [Cuisine: Int] = [:]
            for row in rows {
                if let cuisine = Cuisine(databaseValue: row.cuisine) {
                    result[cuisine] = row.cnt
                }
            }
            return result
        } catch {
            return [:]
        }
    }

    /// Populates `discoveryGeneralRecipes`/`discoveryCuisineRecipes`/`discoveryCuisineOrder`
    /// for the default (no-filter) Recipes tab state. Throttled like `fetchRecipes()`.
    func fetchDiscoverySections(force: Bool = false) async {
        guard userId != nil else { return }
        if let discoveryTask { await discoveryTask.value; return }
        if !force, let last = discoverySectionsFetchedAt, Date().timeIntervalSince(last) < 60 { return }
        let generation = fetchGeneration
        let task = Task { await self.loadDiscoverySections(generation: generation) }
        discoveryTask = task
        await task.value
        if fetchGeneration == generation { discoveryTask = nil }
    }

    private func loadDiscoverySections(generation: UUID) async {
        guard let userId, fetchGeneration == generation, !Task.isCancelled else { return }
        isLoadingDiscoverySections = true
        defer { if fetchGeneration == generation { isLoadingDiscoverySections = false } }
        let counts = await fetchCuisineCounts()
        guard fetchGeneration == generation, !Task.isCancelled else { return }
        let cuisines = counts.filter { $0.value > 0 }
            .sorted { $0.value == $1.value ? $0.key.rawValue < $1.key.rawValue : $0.value > $1.value }
            .prefix(8).map(\.key)
        let filters = Self.generalCategorySpecs.map(\.filter) + cuisines.map { CategoryFilter.cuisine($0) }
        // Keep at most four section queries in flight, then hydrate all unique rows together.
        let results = await withTaskGroup(of: (Int, [RecipeRowWithRelations]?).self) { group in
            var next = 0
            var results: [Int: [RecipeRowWithRelations]] = [:]
            for _ in 0..<min(4, filters.count) {
                let index = next
                group.addTask { (index, try? await self.fetchCategoryRows(filter: filters[index], limit: 6)) }
                next += 1
            }
            for await (index, rows) in group {
                if let rows { results[index] = rows }
                if next < filters.count, !Task.isCancelled {
                    let index = next
                    group.addTask { (index, try? await self.fetchCategoryRows(filter: filters[index], limit: 6)) }
                    next += 1
                }
            }
            return results
        }
        guard fetchGeneration == generation, !Task.isCancelled else { return }
        let uniqueRows = Dictionary(results.values.flatMap { $0 }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        async let nicknames = fetchNicknames(for: Set(uniqueRows.values.map(\.createdBy)))
        async let ratings = fetchUserRatings(for: Array(uniqueRows.keys), userId: userId)
        let (nicknameMap, ratingMap) = await (nicknames, ratings)
        guard fetchGeneration == generation, !Task.isCancelled else { return }
        let recipes = uniqueRows.mapValues { row in
            var recipe = row.toRecipe(nicknameMap: nicknameMap)
            if let rating = ratingMap[row.id] {
                recipe.userRating = rating.rating
                recipe.review = rating.review
            }
            return recipe
        }
        for (index, spec) in Self.generalCategorySpecs.enumerated() {
            if let rows = results[index] { discoveryGeneralRecipes[spec.title] = rows.compactMap { recipes[$0.id] } }
        }
        for (index, cuisine) in cuisines.enumerated() {
            if let rows = results[index + Self.generalCategorySpecs.count] {
                discoveryCuisineRecipes[cuisine] = rows.compactMap { recipes[$0.id] }
            }
        }
        discoveryCuisineOrder = cuisines
        if results.count == filters.count { discoverySectionsFetchedAt = Date() }
    }

    // MARK: - Fetch Community Reviews

    func fetchCommunityReviews(for recipeId: UUID) async {
        if let last = reviewsFetchedAt[recipeId],
           Date().timeIntervalSince(last) < 300,
           communityReviews[recipeId] != nil { return }
        do {
            let rows: [CommunityReviewRow] = try await client
                .from("recipe_ratings")
                .select("user_id, rating, review, created_at")
                .eq("recipe_id", value: recipeId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value

            guard !rows.isEmpty else {
                communityReviews[recipeId] = []
                reviewsFetchedAt[recipeId] = Date()
                return
            }

            // Fetch reviewer profiles
            let reviewerIds = Set(rows.map { $0.userId })
            let profileRows: [ReviewerProfileRow] = try await client
                .from("profiles")
                .select("id, nickname, avatar_path")
                .in("id", values: reviewerIds.map { $0.uuidString })
                .execute()
                .value

            let profileMap = Dictionary(uniqueKeysWithValues: profileRows.map { ($0.id, $0) })

            let reviews = rows.compactMap { row -> CommunityReview? in
                guard let profile = profileMap[row.userId],
                      let nickname = profile.nickname else { return nil }
                return CommunityReview(
                    userId: row.userId,
                    nickname: nickname,
                    avatarPath: profile.avatarPath,
                    rating: row.rating,
                    review: row.review,
                    createdAt: row.createdAt
                )
            }
            communityReviews[recipeId] = reviews
            reviewsFetchedAt[recipeId] = Date()
        } catch {
            // Non-critical — silently fail
        }
    }

    // MARK: - Add Shared Recipe

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
        cuisine: Cuisine,
        dietType: String = "any",
        dietaryRestrictions: [String] = [],
        tags: [String] = [],
        isPublic: Bool = false,
        isUserShared: Bool = true
    ) async throws {
        guard let userId = getUserId() else {
            throw NSError(domain: "SavedRecipesStore", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }

        var mergedTags: [String] = []
        let deterministicTags = Recipe.deterministicTags(timeMinutes: timeMinutes, calories: macros.calories, proteinG: macros.proteinG)
        for tag in deterministicTags + tags where !mergedTags.contains(tag) {
            mergedTags.append(tag)
        }

        if isUserShared {
            let textToCheck = ([title, summary] + steps).joined(separator: " ")
            guard !ContentModerationFilter.containsObjectionableContent(textToCheck) else {
                throw NSError(domain: "SavedRecipesStore", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "This recipe contains language that isn't allowed in shared content. Please revise it and try again."
                ])
            }
        }

        // Optimistic local insert so the recipe appears immediately in the UI
        let tempRecipe = Recipe(
            title: title,
            summary: summary,
            timeMinutes: timeMinutes,
            servings: servings,
            ingredientsUsed: ingredients,
            missingIngredients: [],
            steps: steps,
            macros: macros,
            sources: sources,
            isUserShared: isUserShared,
            imageData: imageData,
            cuisine: cuisine,
            createdByName: currentUserNickname,
            tags: mergedTags
        )
        if isUserShared {
            sharedRecipes.insert(tempRecipe, at: 0)
        } else {
            savedRecipes.insert(tempRecipe, at: 0)
        }

        do {
            // Upload image if provided
            var imagePath: String?
            if let imageData {
                let compressedData = await Task.detached(priority: .userInitiated) {
                    Self.compressImage(imageData)
                }.value
                let fileName = "\(userId.uuidString.lowercased())/\(UUID().uuidString).jpg"
                try await client.storage
                    .from("recipe-images")
                    .upload(fileName, data: compressedData, options: .init(contentType: "image/jpeg"))
                imagePath = fileName
            }

            // Insert recipe row
            let insert = RecipeInsert(
                createdBy: userId,
                title: title,
                summary: summary,
                timeMinutes: timeMinutes,
                servings: servings,
                steps: steps,
                cuisine: cuisine.databaseValue,
                isUserShared: isUserShared,
                imagePath: imagePath,
                calories: macros.calories,
                proteinG: macros.proteinG,
                carbsG: macros.carbsG,
                fatG: macros.fatG,
                dietType: dietType,
                dietaryRestrictions: dietaryRestrictions,
                tags: mergedTags,
                isPublic: isPublic
            )

            let insertedRows: [InsertedID] = try await client
                .from("recipes")
                .insert(insert)
                .select("id")
                .execute()
                .value

            guard let insertedRow = insertedRows.first else {
                throw NSError(domain: "SavedRecipesStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Insert succeeded but returned no ID."])
            }

            let recipeId = insertedRow.id

            // Batch-insert ingredients
            let ingredientInserts = ingredients.map { ingredient in
                RecipeIngredientInsert(recipeId: recipeId, kind: "used", name: ingredient.name, quantity: ingredient.quantity)
            }
            if !ingredientInserts.isEmpty {
                try await client.from("recipe_ingredients").insert(ingredientInserts).execute()
            }

            // Batch-insert source links
            let sourceLinkInserts = sources.map { source in
                SourceLinkInsert(recipeId: recipeId, title: source.title, url: source.url.absoluteString)
            }
            if !sourceLinkInserts.isEmpty {
                try await client.from("source_links").insert(sourceLinkInserts).execute()
            }

            // Cookbook recipes need a saved_recipes entry so they appear in the cookbook
            if !isUserShared {
                try await client
                    .from("saved_recipes")
                    .insert(SavedRecipeInsert(userId: userId, recipeId: recipeId))
                    .execute()
            }

            // Replace temp recipe with the confirmed server version
            let serverRecipe = Recipe(
                id: recipeId,
                title: title,
                summary: summary,
                timeMinutes: timeMinutes,
                servings: servings,
                ingredientsUsed: ingredients,
                missingIngredients: [],
                steps: steps,
                macros: macros,
                sources: sources,
                isUserShared: isUserShared,
                imagePath: imagePath,
                cuisine: cuisine,
                createdBy: userId.uuidString,
                createdByName: currentUserNickname
            )
            if isUserShared {
                if let index = sharedRecipes.firstIndex(where: { $0.id == tempRecipe.id }) {
                    sharedRecipes[index] = serverRecipe
                }
            } else {
                if let index = savedRecipes.firstIndex(where: { $0.id == tempRecipe.id }) {
                    savedRecipes[index] = serverRecipe
                }
            }
        } catch {
            // Rollback the optimistic insert and re-throw so the caller can show the error
            if isUserShared { sharedRecipes.removeAll { $0.id == tempRecipe.id } }
            else { savedRecipes.removeAll { $0.id == tempRecipe.id } }
            throw error
        }
    }

    // MARK: - Toggle Saved (Bookmark)

    func isSaved(_ recipe: Recipe) -> Bool {
        savedRecipes.contains(where: { $0.id == recipe.id })
    }

    func saveRecipe(_ recipe: Recipe) {
        guard !isSaved(recipe) else { return }

        performOptimistic(
            apply: { savedRecipes.insert(recipe, at: 0) },
            rollback: { self.savedRecipes.removeAll { $0.id == recipe.id } }
        ) {
            guard let userId = self.getUserId() else {
                self.savedRecipes.removeAll { $0.id == recipe.id }
                return
            }
            let insert = SavedRecipeInsert(userId: userId, recipeId: recipe.id)
            try await self.client
                .from("saved_recipes")
                .insert(insert)
                .execute()
        }
    }

    func saveGeneratedRecipe(_ recipe: Recipe) {
        guard !isSaved(recipe) else { return }

        performOptimistic(
            apply: { savedRecipes.insert(recipe, at: 0) },
            rollback: { self.savedRecipes.removeAll { $0.id == recipe.id } }
        ) {
            guard let userId = self.getUserId() else {
                self.savedRecipes.removeAll { $0.id == recipe.id }
                return
            }
            let insert = AIRecipeInsert(recipe: recipe, createdBy: userId)
            try await self.client.from("recipes").insert(insert).execute()

            let ingredientInserts =
                recipe.ingredientsUsed.map {
                    RecipeIngredientInsert(recipeId: recipe.id, kind: "used", name: $0.name, quantity: $0.quantity)
                } +
                recipe.missingIngredients.map {
                    RecipeIngredientInsert(recipeId: recipe.id, kind: "missing", name: $0.name, quantity: $0.quantity)
                }
            if !ingredientInserts.isEmpty {
                try await self.client.from("recipe_ingredients").insert(ingredientInserts).execute()
            }

            try await self.client.from("saved_recipes")
                .insert(SavedRecipeInsert(userId: userId, recipeId: recipe.id))
                .execute()
        }
    }

    func unsaveRecipe(_ recipe: Recipe) {
        guard let index = savedRecipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        let removed = savedRecipes[index]
        let removedCollections = savedRecipeCollections[recipe.id] ?? []

        performOptimistic(
            apply: {
                savedRecipes.remove(at: index)
                savedRecipeCollections.removeValue(forKey: recipe.id)
            },
            rollback: {
                self.savedRecipes.insert(removed, at: min(index, self.savedRecipes.count))
                if !removedCollections.isEmpty { self.savedRecipeCollections[recipe.id] = removedCollections }
            }
        ) {
            guard let userId = self.getUserId() else {
                self.savedRecipes.insert(removed, at: min(index, self.savedRecipes.count))
                if !removedCollections.isEmpty { self.savedRecipeCollections[recipe.id] = removedCollections }
                return
            }
            try await self.client
                .from("saved_recipes")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("recipe_id", value: recipe.id.uuidString)
                .execute()

            // Best-effort cleanup — a recipe's saved_recipes row is separate from its
            // collection_recipes rows (which reference the shared `recipes` row, not the
            // bookmark). Without this, unsaving then re-saving later would silently resurrect the
            // recipe into its old collections. Isolated in its own catch so a failure here can't
            // roll back the unsave itself, which already succeeded above.
            do {
                try await self.client
                    .from("collection_recipes")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("recipe_id", value: recipe.id.uuidString)
                    .execute()
            } catch {
                // Best-effort cleanup — the recipe is already unsaved either way.
            }
        }
    }

    // MARK: - Collections

    /// Shared query logic for collections, their recipe membership, and the recipe rows those
    /// memberships point at — used by both `fetchCollections()` and `fetchRecipes()`'s best-effort
    /// embedded refresh. Fetching the member recipes here (rather than relying on them happening to
    /// be present in `savedRecipes`/`communityRecipes`/`sharedRecipes`) is what makes a collection's
    /// contents resolvable from the collection itself.
    // MARK: - Collections

    /// Shared query logic for collections, their recipe membership, and the recipe rows those
    /// memberships point at — used by both `fetchCollections()` and `fetchRecipes()`'s best-effort
    /// embedded refresh. Fetching the member recipes here (rather than relying on them happening to
    /// be present in `savedRecipes`/`communityRecipes`/`sharedRecipes`) is what makes a collection's
    /// contents resolvable from the collection itself.
    private func fetchCollectionsAndMembership(userId: UUID) async throws -> (collections: [RecipeCollection], membership: [UUID: Set<UUID>], recipes: [UUID: Recipe]) {
        async let collectionRowsTask: [CollectionRow] = client
            .from("collections")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        async let collectionRecipeRowsTask: [CollectionRecipeRow] = client
            .from("collection_recipes")
            .select("collection_id, recipe_id")
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        let (collectionRows, collectionRecipeRows) = try await (collectionRowsTask, collectionRecipeRowsTask)
        var collMap: [UUID: Set<UUID>] = [:]
        for row in collectionRecipeRows {
            collMap[row.recipeId, default: []].insert(row.collectionId)
        }

        var recipeMap: [UUID: Recipe] = [:]
        let memberRecipeIds = Set(collectionRecipeRows.map { $0.recipeId })
        if !memberRecipeIds.isEmpty {
            let memberRows: [RecipeRowWithRelations] = try await client
                .from("recipes")
                .select("*, recipe_ingredients(*), source_links(*)")
                .in("id", values: memberRecipeIds.map { $0.uuidString })
                .execute()
                .value
            let nicknameMap = await fetchNicknames(for: Set(memberRows.map { $0.createdBy }))
            for row in memberRows {
                let recipe = row.toRecipe(nicknameMap: nicknameMap)
                recipeMap[recipe.id] = recipe
            }
        }

        return (collectionRows.map { $0.toCollection() }, collMap, recipeMap)
    }

    /// Force-refresh collections *and* their membership outside the 60s `fetchRecipes()` throttle —
    /// the authoritative, retriable entry point. `fetchRecipes()`'s own embedded collections fetch
    /// is best-effort and swallows failures; this method is called, unthrottled, every time the
    /// Collections tab or the save-to-collection picker appears, so it self-heals that gap.
    func fetchCollections() async {
        guard let userId = getUserId() else { return }
        do {
            let (fetchedCollections, membership, memberRecipes) = try await fetchCollectionsAndMembership(userId: userId)
            collections = fetchedCollections
            savedRecipeCollections = membership
            collectionRecipeCache = memberRecipes
        } catch {
            self.error = error.localizedDescription
        }
    }

    @discardableResult
    func createCollection(name: String) async throws -> RecipeCollection {
        guard getUserId() != nil else {
            throw NSError(domain: "SavedRecipesStore", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "SavedRecipesStore", code: 3, userInfo: [NSLocalizedDescriptionKey: "Collection name can't be empty."])
        }
        do {
            let insertedRows: [CollectionRow] = try await client
                .from("collections")
                .insert(CollectionInsert(name: trimmed))
                .select()
                .execute()
                .value
            guard let row = insertedRows.first else {
                throw NSError(domain: "SavedRecipesStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Insert succeeded but returned no row."])
            }
            let collection = row.toCollection()
            collections.append(collection)
            return collection
        } catch {
            throw error
        }
    }

    func deleteCollection(_ collection: RecipeCollection) {
        let removedIndex = collections.firstIndex(where: { $0.id == collection.id })
        let removed = removedIndex.map { collections[$0] }
        let affectedRecipeIds = savedRecipeCollections.filter { $0.value.contains(collection.id) }.map(\.key)

        performOptimistic(
            apply: {
                if let idx = removedIndex { collections.remove(at: idx) }
                for recipeId in affectedRecipeIds { savedRecipeCollections[recipeId]?.remove(collection.id) }
            },
            rollback: {
                if let removed, let idx = removedIndex { self.collections.insert(removed, at: min(idx, self.collections.count)) }
                for recipeId in affectedRecipeIds { self.savedRecipeCollections[recipeId, default: []].insert(collection.id) }
            }
        ) {
            try await self.client.from("collections").delete().eq("id", value: collection.id.uuidString).execute()
        }
    }

    /// Saves `recipe` first if it isn't already saved, then adds it to `collectionIds` — awaited in
    /// strict order (recipe row, then collection membership) instead of as two independent,
    /// unordered persists. All writes are idempotent upserts rather than plain inserts, so a retry
    /// after a partial failure always re-attempts instead of silently no-op-ing.
    func saveAndAddToCollections(_ recipe: Recipe, toCollections collectionIds: Set<UUID>) async throws {
        guard let userId = getUserId() else {
            throw NSError(domain: "SavedRecipesStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "You need to be signed in to save."])
        }

        let wasSavedLocally = isSaved(recipe)
        let previousCollections = savedRecipeCollections[recipe.id] ?? []

        if !wasSavedLocally { savedRecipes.insert(recipe, at: 0) }
        if !collectionIds.isEmpty {
            savedRecipeCollections[recipe.id, default: []].formUnion(collectionIds)
            collectionRecipeCache[recipe.id] = recipe
        }

        do {
            if recipe.isAIGenerated {
                // ON CONFLICT DO NOTHING + returning: only a genuinely new row comes back, so the
                // ingredient rows (which have generated ids and would otherwise duplicate) are
                // written exactly once even if this recipe was saved, unsaved, and saved again.
                let insertedRecipes: [RecipeIDRow] = try await client.from("recipes")
                    .upsert(AIRecipeInsert(recipe: recipe, createdBy: userId), onConflict: "id", ignoreDuplicates: true)
                    .select("id")
                    .execute()
                    .value
                if !insertedRecipes.isEmpty {
                    let ingredientInserts =
                        recipe.ingredientsUsed.map { RecipeIngredientInsert(recipeId: recipe.id, kind: "used", name: $0.name, quantity: $0.quantity) } +
                        recipe.missingIngredients.map { RecipeIngredientInsert(recipeId: recipe.id, kind: "missing", name: $0.name, quantity: $0.quantity) }
                    if !ingredientInserts.isEmpty {
                        try await client.from("recipe_ingredients").insert(ingredientInserts).execute()
                    }
                }
            }

            // Upsert rather than insert, and unconditionally rather than gated on `isSaved`: local
            // state can believe a recipe isn't saved while the row exists in the DB (the recipe is
            // only in `savedRecipes` if it survived the RLS read), and a plain insert would then
            // fail the (user_id, recipe_id) primary key and abort before the collection write below.
            try await client.from("saved_recipes")
                .upsert(SavedRecipeInsert(userId: userId, recipeId: recipe.id), onConflict: "user_id,recipe_id", ignoreDuplicates: true)
                .execute()

            if !collectionIds.isEmpty {
                // Always write the full selection instead of only the ids missing from local state,
                // so a retry can always repair a membership that never actually persisted;
                // (collection_id, recipe_id) is the primary key, so re-writing an existing pair is
                // harmless.
                let inserts = collectionIds.map { CollectionRecipeInsert(collectionId: $0, recipeId: recipe.id) }
                try await client.from("collection_recipes")
                    .upsert(inserts, onConflict: "collection_id,recipe_id", ignoreDuplicates: true)
                    .execute()
            }
        } catch {
            if !wasSavedLocally { savedRecipes.removeAll { $0.id == recipe.id } }
            savedRecipeCollections[recipe.id] = previousCollections
            throw error
        }
    }

    func removeRecipe(_ recipe: Recipe, from collectionId: UUID) {
        guard let userId = getUserId() else { return }
        let previous = savedRecipeCollections[recipe.id] ?? []

        performOptimistic(
            apply: { savedRecipeCollections[recipe.id]?.remove(collectionId) },
            rollback: { self.savedRecipeCollections[recipe.id] = previous }
        ) {
            try await self.client
                .from("collection_recipes")
                .delete()
                .eq("collection_id", value: collectionId.uuidString)
                .eq("recipe_id", value: recipe.id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
        }
    }

    /// Driven by the membership map, not by whatever happens to be loaded elsewhere: every recipe
    /// the collection contains is resolved from the live arrays first (so in-session edits and
    /// ratings are reflected), falling back to `collectionRecipeCache`. A valid membership row
    /// renders regardless of what else happens to be loaded in `savedRecipes`/`communityRecipes`/
    /// `sharedRecipes`.
    func recipes(in collectionId: UUID) -> [Recipe] {
        let memberIds = Set(savedRecipeCollections.compactMap { $0.value.contains(collectionId) ? $0.key : nil })
        guard !memberIds.isEmpty else { return [] }

        var seen = Set<UUID>()
        var result: [Recipe] = []
        // Live copies first, in the existing display order, so in-session edits and ratings show.
        for recipe in savedRecipes + communityRecipes + sharedRecipes where memberIds.contains(recipe.id) {
            if seen.insert(recipe.id).inserted { result.append(recipe) }
        }
        // Then members only the cache can resolve. Sorted, since dictionary order isn't stable and
        // the list would otherwise reshuffle between renders.
        for id in memberIds.subtracting(seen).sorted(by: { $0.uuidString < $1.uuidString }) {
            if let recipe = collectionRecipeCache[id] { result.append(recipe) }
        }
        return result
    }

    /// Pure query helper for a collage cover — the first `limit` recipes in `recipes(in:)`'s
    /// existing order (both `savedRecipes` and `communityRecipes` are fetched newest-first, so this
    /// is stable: same 3 covers, same order, every call — no reshuffling on re-render, on
    /// navigating back from a collection's detail view, or across app relaunches.
    func collectionCoverRecipes(for collectionId: UUID, limit: Int = 3) -> [Recipe] {
        Array(recipes(in: collectionId).prefix(limit))
    }

    // MARK: - Update Recipe Image

    func updateRecipeImage(_ recipe: Recipe, imageData: Data) async throws {
        guard let userId = getUserId() else {
            throw NSError(domain: "SavedRecipesStore", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        let compressedData = await Task.detached(priority: .userInitiated) {
            Self.compressImage(imageData)
        }.value
        let path = "\(userId.uuidString.lowercased())/\(recipe.id.uuidString.lowercased()).jpg"
        let options = FileOptions(contentType: "image/jpeg", upsert: false)

        // update() replaces existing; upload() creates for first-time (mirrors ProfileService.uploadAvatar)
        do {
            try await client.storage.from("recipe-images").update(path, data: compressedData, options: options)
        } catch {
            try await client.storage.from("recipe-images").upload(path, data: compressedData, options: options)
        }

        try await client
            .from("recipes")
            .update(["image_path": path])
            .eq("id", value: recipe.id.uuidString)
            .execute()

        // The filename is deterministic (reused across edits), so stale cache entries
        // under the old path/recipeID must be evicted or every other screen keeps
        // showing the previous photo.
        RecipeImageCache.shared.removeImage(for: recipe.id)
        RecipeImageDiskCache.remove(for: path)

        for index in savedRecipes.indices where savedRecipes[index].id == recipe.id {
            savedRecipes[index].imagePath = path
            savedRecipes[index].imageData = compressedData
        }
        for index in sharedRecipes.indices where sharedRecipes[index].id == recipe.id {
            sharedRecipes[index].imagePath = path
            sharedRecipes[index].imageData = compressedData
        }
        for index in communityRecipes.indices where communityRecipes[index].id == recipe.id {
            communityRecipes[index].imagePath = path
            communityRecipes[index].imageData = compressedData
        }
    }

    func deleteRecipe(_ recipe: Recipe) {
        let savedIdx = savedRecipes.firstIndex(where: { $0.id == recipe.id })
        let sharedIdx = sharedRecipes.firstIndex(where: { $0.id == recipe.id })
        let communityIdx = communityRecipes.firstIndex(where: { $0.id == recipe.id })
        let savedCollections = savedRecipeCollections[recipe.id] ?? []

        performOptimistic(
            apply: {
                if let idx = savedIdx { savedRecipes.remove(at: idx) }
                if let idx = sharedIdx { sharedRecipes.remove(at: idx) }
                if let idx = communityIdx { communityRecipes.remove(at: idx) }
                savedRecipeCollections.removeValue(forKey: recipe.id)
            },
            rollback: {
                if let idx = savedIdx { self.savedRecipes.insert(recipe, at: min(idx, self.savedRecipes.count)) }
                if let idx = sharedIdx { self.sharedRecipes.insert(recipe, at: min(idx, self.sharedRecipes.count)) }
                if let idx = communityIdx { self.communityRecipes.insert(recipe, at: min(idx, self.communityRecipes.count)) }
                if !savedCollections.isEmpty { self.savedRecipeCollections[recipe.id] = savedCollections }
            }
        ) {
            try await self.client
                .from("recipes")
                .delete()
                .eq("id", value: recipe.id.uuidString)
                .execute()
        }
    }

    // MARK: - Rate Recipe

    func rateRecipe(_ recipe: Recipe, rating: Int, review: String? = nil) {
        let clamped = Double(min(max(rating, 1), 5))
        let trimmedReview = review?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalReview = (trimmedReview?.isEmpty ?? true) ? nil : trimmedReview

        // Snapshot previous state for rollback
        struct Snapshot {
            let index: Int
            let userRating: Double?
            let review: String?
        }

        func applyRating(on recipes: inout [Recipe]) -> Snapshot? {
            guard let idx = recipes.firstIndex(where: { $0.id == recipe.id }) else { return nil }
            let snap = Snapshot(index: idx, userRating: recipes[idx].userRating, review: recipes[idx].review)
            recipes[idx].userRating = clamped
            recipes[idx].review = finalReview
            return snap
        }

        func rollbackRating(on recipes: inout [Recipe], snap: Snapshot?) {
            guard let snap else { return }
            recipes[snap.index].userRating = snap.userRating
            recipes[snap.index].review = snap.review
        }

        var sharedSnap: Snapshot?
        var savedSnap: Snapshot?
        var communitySnap: Snapshot?

        performOptimistic(
            apply: {
                sharedSnap = applyRating(on: &sharedRecipes)
                savedSnap = applyRating(on: &savedRecipes)
                communitySnap = applyRating(on: &communityRecipes)
            },
            rollback: {
                rollbackRating(on: &self.sharedRecipes, snap: sharedSnap)
                rollbackRating(on: &self.savedRecipes, snap: savedSnap)
                rollbackRating(on: &self.communityRecipes, snap: communitySnap)
            }
        ) {
            guard let userId = self.getUserId() else { return }
            let ratingInsert = RatingInsert(
                userId: userId,
                recipeId: recipe.id,
                rating: clamped,
                review: finalReview
            )
            try await self.client
                .from("recipe_ratings")
                .upsert(ratingInsert)
                .execute()
            self.reviewsFetchedAt.removeValue(forKey: recipe.id)
            await self.fetchCommunityReviews(for: recipe.id)
        }
    }

    // MARK: - Report Recipe

    private struct ReportInsert: Encodable {
        let recipeId: UUID
        let reporterId: UUID
        let category: String
        let description: String?

        enum CodingKeys: String, CodingKey {
            case recipeId = "recipe_id"
            case reporterId = "reporter_id"
            case category, description
        }
    }

    func reportRecipe(_ recipe: Recipe, category: String, description: String?) async throws {
        guard let userId = getUserId() else {
            throw NSError(domain: "SavedRecipesStore", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        let insert = ReportInsert(
            recipeId: recipe.id,
            reporterId: userId,
            category: category,
            description: description
        )
        try await client.from("recipe_reports").insert(insert).execute()
    }

    private struct ReviewReportInsert: Encodable {
        let recipeId: UUID
        let reviewerUserId: UUID
        let reporterId: UUID
        let category: String
        let description: String?

        enum CodingKeys: String, CodingKey {
            case recipeId = "recipe_id"
            case reviewerUserId = "reviewer_user_id"
            case reporterId = "reporter_id"
            case category, description
        }
    }

    func reportReview(_ review: CommunityReview, recipeId: UUID, category: String, description: String?) async throws {
        guard let userId = getUserId() else {
            throw NSError(domain: "SavedRecipesStore", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        let insert = ReviewReportInsert(
            recipeId: recipeId,
            reviewerUserId: review.userId,
            reporterId: userId,
            category: category,
            description: description
        )
        try await client.from("review_reports").insert(insert).execute()
    }

    private struct UserReportInsert: Encodable {
        let reportedUserId: UUID
        let reporterId: UUID
        let category: String
        let description: String?

        enum CodingKeys: String, CodingKey {
            case reportedUserId = "reported_user_id"
            case reporterId = "reporter_id"
            case category, description
        }
    }

    func reportUser(_ reportedUserId: UUID, category: String, description: String?) async throws {
        guard let userId = getUserId() else {
            throw NSError(domain: "SavedRecipesStore", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        let insert = UserReportInsert(reportedUserId: reportedUserId, reporterId: userId, category: category, description: description)
        try await client.from("user_reports").insert(insert).execute()
    }

    private struct FeedbackInsert: Encodable {
        let reporterId: UUID
        let kind: String
        let title: String
        let description: String

        enum CodingKeys: String, CodingKey {
            case reporterId = "reporter_id"
            case kind, title, description
        }
    }

    private func submitFeedback(kind: String, title: String, description: String) async throws {
        guard let userId = getUserId() else {
            throw NSError(domain: "SavedRecipesStore", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        let insert = FeedbackInsert(reporterId: userId, kind: kind, title: title, description: description)
        try await client.from("feedback_submissions").insert(insert).execute()
    }

    func reportBug(title: String, description: String) async throws {
        try await submitFeedback(kind: "bug", title: title, description: description)
    }

    func requestFeature(title: String, description: String) async throws {
        try await submitFeedback(kind: "feature", title: title, description: description)
    }

    // MARK: - Block Users

    private struct BlockInsert: Encodable {
        let blockerId: UUID
        let blockedId: UUID

        enum CodingKeys: String, CodingKey {
            case blockerId = "blocker_id"
            case blockedId = "blocked_id"
        }
    }

    private struct BlockedUserRow: Decodable {
        let blockedId: UUID

        enum CodingKeys: String, CodingKey {
            case blockedId = "blocked_id"
        }
    }

    func blockUser(_ blockedUserId: UUID) async throws {
        guard let userId = getUserId() else {
            throw NSError(domain: "SavedRecipesStore", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        let insert = BlockInsert(blockerId: userId, blockedId: blockedUserId)
        try await client.from("blocked_users").insert(insert).execute()
        lastFetchedAt = nil
        await fetchRecipes()
    }

    func unblockUser(_ blockedUserId: UUID) async throws {
        guard let userId = getUserId() else {
            throw NSError(domain: "SavedRecipesStore", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
        }
        try await client
            .from("blocked_users")
            .delete()
            .eq("blocker_id", value: userId.uuidString)
            .eq("blocked_id", value: blockedUserId.uuidString)
            .execute()
        lastFetchedAt = nil
        await fetchRecipes()
    }

    // MARK: - Data Export

    /// Every recipe authored by the current user — private (cookbook/AI-generated) and shared
    /// alike. Unlike `communityRecipes`/`sharedRecipes` (which only cover `is_user_shared == true`),
    /// this queries `recipes` directly by `created_by` so private recipes are included too.
    func fetchOwnRecipes() async -> [Recipe] {
        guard let userId = getUserId() else { return [] }
        do {
            let rows: [RecipeRowWithRelations] = try await client
                .from("recipes")
                .select("*, recipe_ingredients(*), source_links(*)")
                .eq("created_by", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            let nicknameMap = await fetchNicknames(for: Set(rows.map { $0.createdBy }))
            return rows.map { $0.toRecipe(nicknameMap: nicknameMap) }
        } catch {
            return []
        }
    }

    /// Every rating/review the current user has ever left, independent of which recipes happen to
    /// be loaded in memory — unlike `fetchUserRatings(for:userId:)`, which only covers recipe IDs
    /// already loaded elsewhere.
    func fetchAllUserRatings() async -> [(recipeId: UUID, rating: Double, review: String?)] {
        guard let userId = getUserId() else { return [] }
        do {
            let rows: [UserRatingRow] = try await client
                .from("recipe_ratings")
                .select("recipe_id, rating, review")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            return rows.map { (recipeId: $0.recipeId, rating: $0.rating, review: $0.review) }
        } catch {
            return []
        }
    }

    func fetchBlockedUsers() async -> [BlockedUser] {
        guard let userId = getUserId() else { return [] }
        do {
            let rows: [BlockedUserRow] = try await client
                .from("blocked_users")
                .select("blocked_id")
                .eq("blocker_id", value: userId.uuidString)
                .execute()
                .value
            let blockedIds = Set(rows.map { $0.blockedId })
            let nicknameMap = await fetchNicknames(for: blockedIds)
            return blockedIds.map { id in
                BlockedUser(id: id, nickname: nicknameMap[id.uuidString] ?? "Unknown user")
            }.sorted { $0.nickname < $1.nickname }
        } catch {
            return []
        }
    }

    // MARK: - Helpers

    private nonisolated static func compressImage(_ data: Data) -> Data {
        guard let uiImage = UIImage(data: data) else { return data }
        return uiImage.jpegData(compressionQuality: 0.7) ?? data
    }
}
