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
    let imagePath: String?
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    let avgRating: Double
    let ratingCount: Int
    let dietType: String?
    let dietaryRestrictions: [String]?
    let recipeIngredients: [RecipeIngredientRow]
    let sourceLinks: [SourceLinkRow]

    enum CodingKeys: String, CodingKey {
        case id
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
        case avgRating = "avg_rating"
        case ratingCount = "rating_count"
        case dietType = "diet_type"
        case dietaryRestrictions = "dietary_restrictions"
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
            dietaryRestrictions: dietaryRestrictions ?? []
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
    let category: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case recipeId = "recipe_id"
        case category
    }
}

/// Encodable payload for inserting into `saved_recipes`.
private struct SavedRecipeInsert: Encodable {
    let userId: UUID
    let recipeId: UUID
    let category: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case recipeId = "recipe_id"
        case category
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(recipeId, forKey: .recipeId)
        try container.encodeIfPresent(category, forKey: .category)
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
    @Published private(set) var savedRecipeCategories: [UUID: String] = [:]
    @Published private(set) var isLoading = false
    @Published var error: String?

    var userId: UUID?
    var currentUserNickname: String?
    private var lastFetchedAt: Date?
    private var reviewsFetchedAt: [UUID: Date] = [:]
    private let client = SupabaseManager.client

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
        savedRecipeCategories = [:]
        lastFetchedAt = nil
        error = nil
    }

    // MARK: - Fetch

    /// Decodable row for looking up nicknames from `profiles`.
    private struct NicknameRow: Decodable {
        let id: UUID
        let nickname: String?
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

    func fetchRecipes() async {
        if let last = lastFetchedAt, Date().timeIntervalSince(last) < 60, !communityRecipes.isEmpty || !savedRecipes.isEmpty || !sharedRecipes.isEmpty { return }
        guard let userId = getUserId() else { return }
        isLoading = true
        error = nil

        do {
            // Fetch community recipes and bookmark IDs in parallel
            async let communityRowsTask: [RecipeRowWithRelations] = client
                .from("recipes")
                .select("*, recipe_ingredients(*), source_links(*)")
                .eq("is_user_shared", value: true)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            async let bookmarkRowsTask: [SavedRecipeRow] = client
                .from("saved_recipes")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            let (communityRows, bookmarkRows) = try await (communityRowsTask, bookmarkRowsTask)

            // Build category map from bookmarks
            var categoryMap: [UUID: String] = [:]
            for row in bookmarkRows {
                if let cat = row.category {
                    categoryMap[row.recipeId] = cat
                }
            }
            savedRecipeCategories = categoryMap

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

            communityRecipes = communityRows.map { $0.toRecipe(nicknameMap: nicknameMap) }
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
            let allRecipeIds = communityRecipes.map(\.id) + savedRecipes.filter { r in !communityRecipes.contains(where: { $0.id == r.id }) }.map(\.id)
            let userRatings = await fetchUserRatings(for: allRecipeIds, userId: userId)

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
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Fetch Category Recipes (Paginated)

    enum CategoryFilter {
        case cuisine(Cuisine)
        case lowCalorie(maxCalories: Int)
        case highProtein(minProteinG: Int)
        case quick(maxMinutes: Int)
    }

    func fetchCategoryRecipes(filter: CategoryFilter, limit: Int = 30, offset: Int = 0) async -> [Recipe] {
        do {
            var query = client
                .from("recipes")
                .select("*, recipe_ingredients(*), source_links(*)")
                .eq("is_user_shared", value: true)

            switch filter {
            case .cuisine(let cuisine):
                query = query.eq("cuisine", value: cuisine.databaseValue)
            case .lowCalorie(let max):
                query = query.lte("calories", value: max)
            case .highProtein(let min):
                query = query.gte("protein_g", value: min)
            case .quick(let max):
                query = query.lte("time_minutes", value: max)
            }

            let rows: [RecipeRowWithRelations] = try await query
                .order("created_at", ascending: false)
                .range(from: offset, to: offset + limit - 1)
                .execute()
                .value

            let creatorIds = Set(rows.map { $0.createdBy })
            let nicknameMap = await fetchNicknames(for: creatorIds)
            return rows.map { $0.toRecipe(nicknameMap: nicknameMap) }
        } catch {
            return []
        }
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
        isPublic: Bool = false,
        isUserShared: Bool = true
    ) async throws {
        guard let userId = getUserId() else {
            throw NSError(domain: "SavedRecipesStore", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not signed in."])
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
            createdByName: currentUserNickname
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
                    .insert(SavedRecipeInsert(userId: userId, recipeId: recipeId, category: nil))
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

    func saveRecipe(_ recipe: Recipe, category: String? = nil) {
        guard !isSaved(recipe) else { return }

        performOptimistic(
            apply: {
                savedRecipes.insert(recipe, at: 0)
                if let category { savedRecipeCategories[recipe.id] = category }
            },
            rollback: {
                self.savedRecipes.removeAll { $0.id == recipe.id }
                self.savedRecipeCategories.removeValue(forKey: recipe.id)
            }
        ) {
            guard let userId = self.getUserId() else {
                self.savedRecipes.removeAll { $0.id == recipe.id }
                self.savedRecipeCategories.removeValue(forKey: recipe.id)
                return
            }
            let insert = SavedRecipeInsert(userId: userId, recipeId: recipe.id, category: category)
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
                .insert(SavedRecipeInsert(userId: userId, recipeId: recipe.id, category: nil))
                .execute()
        }
    }

    func unsaveRecipe(_ recipe: Recipe) {
        guard let index = savedRecipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        let removed = savedRecipes[index]
        let removedCategory = savedRecipeCategories[recipe.id]

        performOptimistic(
            apply: {
                savedRecipes.remove(at: index)
                savedRecipeCategories.removeValue(forKey: recipe.id)
            },
            rollback: {
                self.savedRecipes.insert(removed, at: min(index, self.savedRecipes.count))
                if let removedCategory { self.savedRecipeCategories[recipe.id] = removedCategory }
            }
        ) {
            guard let userId = self.getUserId() else {
                self.savedRecipes.insert(removed, at: min(index, self.savedRecipes.count))
                if let removedCategory { self.savedRecipeCategories[recipe.id] = removedCategory }
                return
            }
            try await self.client
                .from("saved_recipes")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("recipe_id", value: recipe.id.uuidString)
                .execute()
        }
    }

    func deleteRecipe(_ recipe: Recipe) {
        let savedIdx = savedRecipes.firstIndex(where: { $0.id == recipe.id })
        let sharedIdx = sharedRecipes.firstIndex(where: { $0.id == recipe.id })
        let communityIdx = communityRecipes.firstIndex(where: { $0.id == recipe.id })
        let savedCategory = savedRecipeCategories[recipe.id]

        performOptimistic(
            apply: {
                if let idx = savedIdx { savedRecipes.remove(at: idx) }
                if let idx = sharedIdx { sharedRecipes.remove(at: idx) }
                if let idx = communityIdx { communityRecipes.remove(at: idx) }
                savedRecipeCategories.removeValue(forKey: recipe.id)
            },
            rollback: {
                if let idx = savedIdx { self.savedRecipes.insert(recipe, at: min(idx, self.savedRecipes.count)) }
                if let idx = sharedIdx { self.sharedRecipes.insert(recipe, at: min(idx, self.sharedRecipes.count)) }
                if let idx = communityIdx { self.communityRecipes.insert(recipe, at: min(idx, self.communityRecipes.count)) }
                if let cat = savedCategory { self.savedRecipeCategories[recipe.id] = cat }
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
