import Foundation
import Supabase
import UIKit

// MARK: - DTOs

/// Decodable row for the `recipes` table.
private struct RecipeRow: Decodable {
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
    }
}

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
            rating: avgRating
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
    @Published private(set) var savedRecipes: [Recipe]
    @Published private(set) var sharedRecipes: [Recipe]
    @Published private(set) var communityRecipes: [Recipe] = []
    @Published private(set) var isLoading = false
    @Published var error: String?

    var userId: UUID?
    private var lastFetchedAt: Date?
    private let client = SupabaseManager.client

    init(
        savedRecipes: [Recipe] = [],
        sharedRecipes: [Recipe] = [],
        communityRecipes: [Recipe] = []
    ) {
        self.savedRecipes = savedRecipes
        self.sharedRecipes = sharedRecipes
        self.communityRecipes = communityRecipes
    }

    private func getUserId() -> UUID? { userId }

    func clearForSignOut() {
        userId = nil
        savedRecipes = []
        sharedRecipes = []
        communityRecipes = []
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

    func fetchRecipes() async {
        if let last = lastFetchedAt, Date().timeIntervalSince(last) < 60, !communityRecipes.isEmpty || !savedRecipes.isEmpty || !sharedRecipes.isEmpty { return }
        guard let userId = getUserId() else { return }
        isLoading = true
        error = nil

        do {
            // Fetch community recipes (limited for initial load)
            let communityRows: [RecipeRowWithRelations] = try await client
                .from("recipes")
                .select("*, recipe_ingredients(*), source_links(*)")
                .eq("is_user_shared", value: true)
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            // Collect unique creator UUIDs and fetch their nicknames
            let creatorIds = Set(communityRows.map { $0.createdBy })
            let nicknameMap = await fetchNicknames(for: creatorIds)

            communityRecipes = communityRows.map { $0.toRecipe(nicknameMap: nicknameMap) }

            // Filter to just current user's shared recipes
            sharedRecipes = communityRecipes.filter { $0.createdBy == userId.uuidString }

            // Fetch saved/bookmarked recipe IDs
            let bookmarkRows: [SavedRecipeRow] = try await client
                .from("saved_recipes")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value

            let savedRecipeIds = bookmarkRows.map { $0.recipeId }

            if !savedRecipeIds.isEmpty {
                let savedRows: [RecipeRowWithRelations] = try await client
                    .from("recipes")
                    .select("*, recipe_ingredients(*), source_links(*)")
                    .in("id", values: savedRecipeIds.map { $0.uuidString })
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                // Fetch nicknames for saved recipe creators too
                let savedCreatorIds = Set(savedRows.map { $0.createdBy })
                let savedNicknameMap = await fetchNicknames(for: savedCreatorIds)

                savedRecipes = savedRows.map { $0.toRecipe(nicknameMap: savedNicknameMap) }
            } else {
                savedRecipes = []
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
        cuisine: Cuisine
    ) {
        // Optimistic local insert
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
            isUserShared: true,
            imageData: imageData,
            cuisine: cuisine
        )
        sharedRecipes.insert(tempRecipe, at: 0)

        Task {
            guard let userId = getUserId() else {
                sharedRecipes.removeAll { $0.id == tempRecipe.id }
                return
            }

            do {
                // Upload image if provided
                var imagePath: String?
                if let imageData {
                    let compressedData = compressImage(imageData)
                    let fileName = "\(userId.uuidString)/\(UUID().uuidString).jpg"
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
                    isUserShared: true,
                    imagePath: imagePath,
                    calories: macros.calories,
                    proteinG: macros.proteinG,
                    carbsG: macros.carbsG,
                    fatG: macros.fatG
                )

                let insertedRows: [RecipeRow] = try await client
                    .from("recipes")
                    .insert(insert)
                    .select()
                    .execute()
                    .value

                guard let insertedRow = insertedRows.first else {
                    sharedRecipes.removeAll { $0.id == tempRecipe.id }
                    return
                }

                let recipeId = insertedRow.id

                // Batch-insert ingredients
                let ingredientInserts = ingredients.map { ingredient in
                    RecipeIngredientInsert(
                        recipeId: recipeId,
                        kind: "used",
                        name: ingredient.name,
                        quantity: ingredient.quantity
                    )
                }

                if !ingredientInserts.isEmpty {
                    try await client
                        .from("recipe_ingredients")
                        .insert(ingredientInserts)
                        .execute()
                }

                // Batch-insert source links
                let sourceLinkInserts = sources.map { source in
                    SourceLinkInsert(
                        recipeId: recipeId,
                        title: source.title,
                        url: source.url.absoluteString
                    )
                }

                if !sourceLinkInserts.isEmpty {
                    try await client
                        .from("source_links")
                        .insert(sourceLinkInserts)
                        .execute()
                }

                // Replace temp recipe with server version
                if let index = sharedRecipes.firstIndex(where: { $0.id == tempRecipe.id }) {
                    var serverRecipe = tempRecipe
                    serverRecipe = Recipe(
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
                        isUserShared: true,
                        imageData: imageData,
                        cuisine: cuisine,
                        createdBy: userId.uuidString
                    )
                    sharedRecipes[index] = serverRecipe
                }
            } catch {
                // Rollback optimistic insert
                sharedRecipes.removeAll { $0.id == tempRecipe.id }
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Toggle Saved (Bookmark)

    func isSaved(_ recipe: Recipe) -> Bool {
        savedRecipes.contains(where: { $0.id == recipe.id })
    }

    func toggleSaved(_ recipe: Recipe) {
        if let index = savedRecipes.firstIndex(where: { $0.id == recipe.id }) {
            // Optimistic remove
            let removed = savedRecipes.remove(at: index)

            Task {
                guard let userId = getUserId() else {
                    savedRecipes.insert(removed, at: min(index, savedRecipes.count))
                    return
                }

                do {
                    try await client
                        .from("saved_recipes")
                        .delete()
                        .eq("user_id", value: userId.uuidString)
                        .eq("recipe_id", value: recipe.id.uuidString)
                        .execute()
                } catch {
                    // Rollback
                    savedRecipes.insert(removed, at: min(index, savedRecipes.count))
                    self.error = error.localizedDescription
                }
            }
        } else {
            // Optimistic add
            savedRecipes.insert(recipe, at: 0)

            Task {
                guard let userId = getUserId() else {
                    savedRecipes.removeAll { $0.id == recipe.id }
                    return
                }

                do {
                    let insert = SavedRecipeInsert(userId: userId, recipeId: recipe.id)
                    try await client
                        .from("saved_recipes")
                        .insert(insert)
                        .execute()
                } catch {
                    // Rollback
                    savedRecipes.removeAll { $0.id == recipe.id }
                    self.error = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Rate Recipe

    func rateRecipe(_ recipe: Recipe, rating: Int, review: String? = nil) {
        let clamped = Double(min(max(rating, 1), 5))
        let trimmedReview = review?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalReview = (trimmedReview?.isEmpty ?? true) ? nil : trimmedReview

        // Optimistic local update
        let previousSharedIndex = sharedRecipes.firstIndex(where: { $0.id == recipe.id })
        let previousSharedRating = previousSharedIndex.map { sharedRecipes[$0].rating }
        let previousSharedReview = previousSharedIndex.map { sharedRecipes[$0].review }

        let previousSavedIndex = savedRecipes.firstIndex(where: { $0.id == recipe.id })
        let previousSavedRating = previousSavedIndex.map { savedRecipes[$0].rating }
        let previousSavedReview = previousSavedIndex.map { savedRecipes[$0].review }

        if let index = previousSharedIndex {
            sharedRecipes[index].rating = clamped
            sharedRecipes[index].review = finalReview
        }
        if let index = previousSavedIndex {
            savedRecipes[index].rating = clamped
            savedRecipes[index].review = finalReview
        }

        Task {
            guard let userId = getUserId() else { return }

            do {
                let ratingInsert = RatingInsert(
                    userId: userId,
                    recipeId: recipe.id,
                    rating: clamped,
                    review: finalReview
                )
                try await client
                    .from("recipe_ratings")
                    .upsert(ratingInsert)
                    .execute()
            } catch {
                // Rollback
                if let index = previousSharedIndex, let prevRating = previousSharedRating {
                    sharedRecipes[index].rating = prevRating
                    sharedRecipes[index].review = previousSharedReview ?? nil
                }
                if let index = previousSavedIndex, let prevRating = previousSavedRating {
                    savedRecipes[index].rating = prevRating
                    savedRecipes[index].review = previousSavedReview ?? nil
                }
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    private func compressImage(_ data: Data) -> Data {
        guard let uiImage = UIImage(data: data) else { return data }
        return uiImage.jpegData(compressionQuality: 0.7) ?? data
    }
}
