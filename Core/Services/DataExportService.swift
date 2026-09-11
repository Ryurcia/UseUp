import Foundation

/// Builds one CSV per data category the app stores about the current user, writing each to the
/// temp directory and returning their URLs for the OS share sheet. Every fetch is best-effort
/// (`try?`) — one category failing to load doesn't block the rest of the export.
enum DataExportService {
    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func string(_ date: Date?) -> String {
        date.map { dateFormatter.string(from: $0) } ?? ""
    }

    @MainActor
    static func exportAll(
        session: AppSession,
        pantryStore: PantryStore,
        savedRecipesStore: SavedRecipesStore,
        userActivityStore: UserActivityStore,
        statsStore: StatsStore? = nil
    ) async -> [URL] {
        var urls: [URL] = []
        func write(_ doc: CSVDocument) {
            if let url = try? doc.write() { urls.append(url) }
        }

        write(buildProfileCSV(session))
        write(buildPantryCSV(pantryStore.ingredients))

        if let statsStore {
            let events = await statsStore.fetchAllPantryEvents()
            write(buildPantryEventsCSV(events))
        }

        let ownRecipes = await savedRecipesStore.fetchOwnRecipes()
        write(buildRecipesCSV(ownRecipes, filename: "my_recipes.csv"))
        write(buildRecipesCSV(savedRecipesStore.savedRecipes, filename: "saved_recipes.csv"))

        let ratings = await savedRecipesStore.fetchAllUserRatings()
        write(buildRatingsCSV(ratings))

        write(buildCollectionsCSV(savedRecipesStore.collections, savedRecipesStore.savedRecipeCollections))

        let activity = await userActivityStore.fetchAllActivity()
        write(buildActivityCSV(activity))

        let history = await pantryStore.fetchAllIngredientHistory()
        write(buildIngredientHistoryCSV(history))

        let blocked = await savedRecipesStore.fetchBlockedUsers()
        write(buildBlockedAccountsCSV(blocked))

        return urls
    }

    /// Stats-only export — the "Export" button in `StatsSection` on the profile screen. Produces
    /// the designed multi-page PDF report. Returns a single-file array so the caller can present
    /// the same `ShareSheet` as the full export. (The raw `pantry_events.csv` stays available via
    /// the full "Export My Data" flow.)
    @MainActor
    static func exportPantryEvents(statsStore: StatsStore) async -> [URL] {
        let events = await statsStore.fetchAllPantryEvents()
        guard let url = StatsPDFReport.generate(events: events) else { return [] }
        return [url]
    }

    // MARK: - Per-category builders

    private static func buildPantryEventsCSV(_ events: [PantryEvent]) -> CSVDocument {
        var doc = CSVDocument(filename: "pantry_events.csv")
        doc.addRow(["occurred_at", "outcome", "ingredient_name", "category", "cost_value"])
        for e in events {
            doc.addRow([
                dateFormatter.string(from: e.occurredAt),
                e.outcome.rawValue,
                e.ingredientName,
                e.category.rawValue,
                e.costValue.map { String(format: "%.2f", $0) } ?? "",
            ])
        }
        return doc
    }

    @MainActor
    private static func buildProfileCSV(_ session: AppSession) -> CSVDocument {
        var doc = CSVDocument(filename: "profile.csv")
        doc.addRow(["nickname", "display_name", "email", "dietary_preference", "dietary_restrictions",
                     "allergies", "cooking_skill_level", "is_premium", "nickname_updated_at"])

        let restrictions = session.currentUserDietaryRestrictions.map(\.rawValue).sorted().joined(separator: "; ")
        var allergies = session.currentUserAllergies.map(\.rawValue).sorted()
        if !session.currentUserCustomAllergy.trimmingCharacters(in: .whitespaces).isEmpty {
            allergies.append(session.currentUserCustomAllergy)
        }

        doc.addRow([
            session.currentUserNickname ?? "",
            session.currentUserDisplayName ?? "",
            session.currentUserEmail ?? "",
            session.currentUserDietaryPreference.rawValue,
            restrictions,
            allergies.joined(separator: "; "),
            String(session.currentUserCookingSkillLevel),
            String(session.isPremium),
            string(session.nicknameUpdatedAt),
        ])
        return doc
    }

    private static func buildPantryCSV(_ ingredients: [Ingredient]) -> CSVDocument {
        var doc = CSVDocument(filename: "pantry.csv")
        doc.addRow(["id", "name", "amount", "unit_count", "category", "location", "expiration_date", "logged_at", "notes"])
        for i in ingredients {
            doc.addRow([
                i.id.uuidString, i.name, i.amount ?? "", String(i.unitCount),
                i.category.rawValue, i.location.rawValue,
                string(i.expirationDate), string(i.loggedAt), i.notes ?? "",
            ])
        }
        return doc
    }

    private static func buildRecipesCSV(_ recipes: [Recipe], filename: String) -> CSVDocument {
        var doc = CSVDocument(filename: filename)
        doc.addRow(["id", "title", "cuisine", "time_minutes", "servings", "diet_type", "dietary_restrictions",
                     "is_ai_generated", "is_user_shared", "rating", "created_by_name",
                     "ingredients_used", "missing_ingredients", "steps", "calories", "protein_g", "carbs_g", "fat_g"])
        for r in recipes {
            doc.addRow([
                r.id.uuidString, r.title, r.cuisine.databaseValue, String(r.timeMinutes), String(r.servings),
                r.dietType, r.dietaryRestrictions.joined(separator: "; "),
                String(r.isAIGenerated), String(r.isUserShared), String(r.rating), r.createdByName ?? "",
                r.ingredientsUsed.map { "\($0.name) (\($0.quantity))" }.joined(separator: "; "),
                r.missingIngredients.map { "\($0.name) (\($0.quantity))" }.joined(separator: "; "),
                r.steps.joined(separator: " / "),
                String(r.macros.calories), String(r.macros.proteinG), String(r.macros.carbsG), String(r.macros.fatG),
            ])
        }
        return doc
    }

    private static func buildRatingsCSV(_ ratings: [(recipeId: UUID, rating: Double, review: String?)]) -> CSVDocument {
        var doc = CSVDocument(filename: "ratings_reviews.csv")
        doc.addRow(["recipe_id", "rating", "review"])
        for r in ratings {
            doc.addRow([r.recipeId.uuidString, String(r.rating), r.review ?? ""])
        }
        return doc
    }

    private static func buildCollectionsCSV(_ collections: [RecipeCollection], _ membership: [UUID: Set<UUID>]) -> CSVDocument {
        var doc = CSVDocument(filename: "collections.csv")
        doc.addRow(["collection_id", "collection_name", "recipe_count", "recipe_ids"])

        var recipeIdsByCollection: [UUID: [UUID]] = [:]
        for (recipeId, collectionIds) in membership {
            for collectionId in collectionIds {
                recipeIdsByCollection[collectionId, default: []].append(recipeId)
            }
        }

        for c in collections {
            let recipeIds = recipeIdsByCollection[c.id] ?? []
            doc.addRow([
                c.id.uuidString, c.name, String(recipeIds.count),
                recipeIds.map(\.uuidString).joined(separator: "; "),
            ])
        }
        return doc
    }

    private static func buildActivityCSV(_ activity: [(eventType: String, createdAt: String?)]) -> CSVDocument {
        var doc = CSVDocument(filename: "activity_history.csv")
        doc.addRow(["event_type", "created_at"])
        for a in activity {
            doc.addRow([a.eventType, a.createdAt ?? ""])
        }
        return doc
    }

    private static func buildIngredientHistoryCSV(
        _ history: [(name: String, category: String, useCount: Int, lastUsedAt: Date?, createdAt: Date?)]
    ) -> CSVDocument {
        var doc = CSVDocument(filename: "ingredient_history.csv")
        doc.addRow(["name", "category", "use_count", "last_used_at", "created_at"])
        for h in history {
            doc.addRow([h.name, h.category, String(h.useCount), string(h.lastUsedAt), string(h.createdAt)])
        }
        return doc
    }

    private static func buildBlockedAccountsCSV(_ blocked: [BlockedUser]) -> CSVDocument {
        var doc = CSVDocument(filename: "blocked_accounts.csv")
        doc.addRow(["nickname"])
        for b in blocked {
            doc.addRow([b.nickname])
        }
        return doc
    }
}
