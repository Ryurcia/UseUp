import Foundation
import Supabase

/// Shared `yyyy-MM-dd` formatter — DateFormatter init is expensive, so reuse one instance.
private let pantryDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

/// Codable row matching the Supabase `ingredients` table.
private struct IngredientRow: Codable {
    let id: UUID
    let userId: UUID
    let name: String
    let amount: String?
    let unitCount: Int
    let quantityEstimate: String?
    let quantitySource: String?
    let category: String
    let location: String
    let expirationDate: String?
    let loggedAt: Date?
    let notes: String?
    let icon: String?
    let notifReadAt: Date?
    let dismissed: Bool
    let estimatedUnitCost: Double?
    let estimatedTotalCost: Double?
    let costUnit: String?
    let costSource: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, amount
        case unitCount = "unit_count"
        case quantityEstimate = "quantity_estimate"
        case quantitySource = "quantity_source"
        case category, location
        case expirationDate = "expiration_date"
        case loggedAt = "logged_at"
        case notes, icon
        case notifReadAt = "notif_read_at"
        case dismissed
        case estimatedUnitCost = "estimated_unit_cost"
        case estimatedTotalCost = "estimated_total_cost"
        case costUnit = "cost_unit"
        case costSource = "cost_source"
    }

    func toIngredient() -> Ingredient {
        let cat = Ingredient.Category(rawValue: category) ?? .other
        let loc = Ingredient.StorageLocation(rawValue: location) ?? .fridge

        var expDate: Date?
        if let expirationDate {
            expDate = pantryDateFormatter.date(from: expirationDate)
        }

        return Ingredient(
            id: id,
            name: name,
            amount: amount,
            unitCount: unitCount,
            quantityEstimate: quantityEstimate.flatMap(Ingredient.QuantityEstimate.init(rawValue:)),
            quantitySource: quantitySource.flatMap(Ingredient.QuantitySource.init(rawValue:)),
            category: cat,
            location: loc,
            expirationDate: expDate,
            loggedAt: loggedAt ?? Date(),
            notes: notes,
            icon: icon,
            notifReadAt: notifReadAt,
            dismissed: dismissed,
            estimatedUnitCost: estimatedUnitCost,
            estimatedTotalCost: estimatedTotalCost,
            costUnit: costUnit,
            costSource: costSource
        )
    }
}

/// Insert/update payload. `id` is normally omitted (server generates it via `gen_random_uuid()`),
/// but a batch insert supplies it explicitly so temp rows can be matched to server rows by id
/// afterward, regardless of return order (same trick as `AIRecipeInsert` in SavedRecipesStore).
private struct IngredientInsert: Encodable {
    var id: UUID? = nil
    let userId: UUID
    let name: String
    let amount: String?
    let unitCount: Int
    let quantityEstimate: String?
    let quantitySource: String?
    let category: String
    let location: String
    let expirationDate: String?
    let notes: String?
    let icon: String?
    var estimatedUnitCost: Double? = nil
    var estimatedTotalCost: Double? = nil
    var costUnit: String? = nil
    var costSource: String? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, amount
        case unitCount = "unit_count"
        case quantityEstimate = "quantity_estimate"
        case quantitySource = "quantity_source"
        case category, location
        case expirationDate = "expiration_date"
        case notes, icon
        case estimatedUnitCost = "estimated_unit_cost"
        case estimatedTotalCost = "estimated_total_cost"
        case costUnit = "cost_unit"
        case costSource = "cost_source"
    }
}

/// Two-field update payload for `useIngredient` — Supabase's `.update()` needs a single
/// `Encodable` value rather than a heterogeneous `[String: Any]` dictionary literal.
private struct UseAmountUpdate: Encodable {
    let amount: String
    let unitCount: Int

    enum CodingKeys: String, CodingKey {
        case amount
        case unitCount = "unit_count"
    }
}

private struct IngredientUpdate: Encodable {
    let name: String
    let amount: String?
    let unitCount: Int
    let quantityEstimate: String?
    let quantitySource: String?
    let category: String
    let location: String
    let expirationDate: String?
    let notes: String?
    let icon: String?
    var estimatedTotalCost: Double? = nil

    enum CodingKeys: String, CodingKey {
        case name, amount
        case unitCount = "unit_count"
        case quantityEstimate = "quantity_estimate"
        case quantitySource = "quantity_source"
        case category, location
        case expirationDate = "expiration_date"
        case notes, icon
        case estimatedTotalCost = "estimated_total_cost"
    }
}

/// A name-autocomplete suggestion sourced from `ingredient_history` — the user's own past
/// ingredient names, kept even after the live pantry item is deleted (used up / removed).
struct IngredientSuggestion: Identifiable {
    let id: String   // name is unique per user in ingredient_history
    let name: String
    let category: Ingredient.Category
}

private struct IngredientHistoryRow: Decodable {
    let name: String
    let category: String
}

/// Full `ingredient_history` row (all columns), used for data export — unlike `IngredientHistoryRow`,
/// which only decodes the two fields `fetchNameSuggestions` needs.
private struct IngredientHistoryFullRow: Decodable {
    let name: String
    let category: String
    let useCount: Int
    let lastUsedAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case name, category
        case useCount = "use_count"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
    }
}

/// Why a pantry item left (or entered) the pantry — one row per event in `pantry_events`,
/// the ledger that backs the Stats screen. `.bought` on add, `.used` when consumed, `.wasted`
/// for any other removal.
enum PantryEventOutcome: String {
    case bought, used, wasted
}

/// Insert payload for `pantry_events`. `user_id` and `occurred_at` are DB-defaulted (omitted).
private struct PantryEventInsert: Encodable {
    let ingredientId: UUID?
    let ingredientName: String
    let ingredientKey: String
    let category: String
    let outcome: String
    let costValue: Double?

    enum CodingKeys: String, CodingKey {
        case ingredientId = "ingredient_id"
        case ingredientName = "ingredient_name"
        case ingredientKey = "ingredient_key"
        case category, outcome
        case costValue = "cost_value"
    }
}

@MainActor
final class PantryStore: ObservableObject {
    static weak var shared: PantryStore?

    @Published private(set) var ingredients: [Ingredient] = []
    @Published private(set) var isLoading = false
    @Published var error: String?
    /// Read state for recipe-suggestion notifications only — those are ephemeral, regenerated per
    /// session from `SuggestedRecipeCache` rather than stable server rows, so unlike expiring-item
    /// read/dismissed state (which lives on `Ingredient.notifReadAt`/`.dismissed`, backed by
    /// Supabase) this stays device-local.
    @Published var recipeNotifReadTimestamps: [String: Date] = [:]
    /// Dismissed recipe-suggestion notification IDs (keyed `"recipe_<notif.id>"`). Device-local for
    /// the same reason as `recipeNotifReadTimestamps` — these notifications aren't stable server rows.
    @Published var dismissedRecipeNotifIDs: Set<String> = []

    var userId: UUID?
    private var lastFetchedAt: Date?
    private let client = SupabaseManager.client
    private var notificationDebounceTask: Task<Void, Never>?

    private static let recipeReadTimestampsKey = "notif_readTimestamps"
    private static let dismissedRecipeNotifIDsKey = "notif_dismissedRecipeIDs"
    private let autoHideInterval: TimeInterval = 3 * 24 * 3600

    // Shared formatter — ISO8601DateFormatter init is expensive, so reuse one instance.
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init() {
        loadRecipeReadTimestamps()
        loadDismissedRecipeNotifIDs()
        PantryStore.shared = self
    }

    func dismissRecipeNotification(_ id: String) {
        guard dismissedRecipeNotifIDs.insert(id).inserted else { return }
        UserDefaults.standard.set(Array(dismissedRecipeNotifIDs), forKey: Self.dismissedRecipeNotifIDsKey)
    }

    private func loadDismissedRecipeNotifIDs() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.dismissedRecipeNotifIDsKey) ?? []
        dismissedRecipeNotifIDs = Set(stored)
    }

    func markRecipeNotificationRead(_ id: String) {
        recipeNotifReadTimestamps[id] = Date()
        saveRecipeReadTimestamps()
    }

    func markAllRecipeNotificationsRead(ids: [String]) {
        let now = Date()
        for id in ids { recipeNotifReadTimestamps[id] = now }
        saveRecipeReadTimestamps()
    }

    func markExpiringNotificationRead(ingredientId: UUID) {
        guard let index = ingredients.firstIndex(where: { $0.id == ingredientId }),
              ingredients[index].notifReadAt == nil else { return }
        let now = Date()

        performOptimistic(
            apply: { ingredients[index].notifReadAt = now },
            rollback: {
                if let idx = self.ingredients.firstIndex(where: { $0.id == ingredientId }) {
                    self.ingredients[idx].notifReadAt = nil
                }
            }
        ) {
            try await self.client
                .from("ingredients")
                .update(["notif_read_at": Self.iso8601.string(from: now)])
                .eq("id", value: ingredientId.uuidString)
                .execute()
        }
    }

    func markAllExpiringNotificationsRead(ids: [UUID]) {
        let now = Date()
        let unreadIds = ids.filter { id in
            ingredients.first(where: { $0.id == id })?.notifReadAt == nil
        }
        guard !unreadIds.isEmpty else { return }

        performOptimistic(
            apply: {
                for id in unreadIds {
                    if let idx = ingredients.firstIndex(where: { $0.id == id }) {
                        ingredients[idx].notifReadAt = now
                    }
                }
            },
            rollback: {
                for id in unreadIds {
                    if let idx = self.ingredients.firstIndex(where: { $0.id == id }) {
                        self.ingredients[idx].notifReadAt = nil
                    }
                }
            }
        ) {
            try await self.client
                .from("ingredients")
                .update(["notif_read_at": Self.iso8601.string(from: now)])
                .in("id", values: unreadIds.map(\.uuidString))
                .execute()
        }
    }

    func dismissNotification(for ingredientId: UUID) {
        guard let index = ingredients.firstIndex(where: { $0.id == ingredientId }) else { return }

        performOptimistic(
            apply: { ingredients[index].dismissed = true },
            rollback: {
                if let idx = self.ingredients.firstIndex(where: { $0.id == ingredientId }) {
                    self.ingredients[idx].dismissed = false
                }
            }
        ) {
            try await self.client
                .from("ingredients")
                .update(["dismissed": true])
                .eq("id", value: ingredientId.uuidString)
                .execute()
            self.rescheduleNotifications()
        }
    }

    /// Dated, non-dismissed ingredients that are expired or expiring within `days` — the single
    /// source of truth for "expiring soon" eligibility, shared by the notification bell badge and
    /// the full notification list so they never disagree on which items qualify.
    func expiringAlertCandidates(withinDays days: Int = 7) -> [Ingredient] {
        ingredients.filter { ingredient in
            guard ingredient.expirationDate != nil else { return false }
            guard !ingredient.dismissed else { return false }
            if ingredient.isExpired { return true }
            guard let daysUntil = ingredient.daysUntilExpiration else { return false }
            return daysUntil <= days
        }
    }

    private func saveRecipeReadTimestamps() {
        let raw = recipeNotifReadTimestamps.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(raw, forKey: Self.recipeReadTimestampsKey)
    }

    private func loadRecipeReadTimestamps() {
        let now = Date()
        let purgeCutoff = now.addingTimeInterval(-7 * 24 * 3600)
        var result: [String: Date] = [:]
        if let raw = UserDefaults.standard.dictionary(forKey: Self.recipeReadTimestampsKey) as? [String: Double] {
            result = raw.mapValues { Date(timeIntervalSince1970: $0) }.filter { $0.value > purgeCutoff }
        }
        recipeNotifReadTimestamps = result
    }

    private func getUserId() -> UUID? { userId }

    /// Applies a local mutation immediately (optimistic update), then runs `persist` (the network
    /// call plus any post-success work, e.g. rescheduling notifications). If `persist` throws, the
    /// local mutation is rolled back and the error surfaced via `self.error`.
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
        ingredients = []
        lastFetchedAt = nil
        error = nil
        dismissedRecipeNotifIDs = []
        UserDefaults.standard.removeObject(forKey: Self.dismissedRecipeNotifIDsKey)
    }

    // MARK: - Fetch

    func fetchIngredients() async {
        if let last = lastFetchedAt, Date().timeIntervalSince(last) < 60, !ingredients.isEmpty { return }
        guard let userId = getUserId() else { return }
        isLoading = true
        error = nil

        do {
            let rows: [IngredientRow] = try await client
                .from("ingredients")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("logged_at", ascending: false)
                .execute()
                .value

            // Preserve any optimistic inserts that are still in-flight (not yet in DB).
            // Their locally-generated UUIDs won't appear in server results.
            let serverIds = Set(rows.map(\.id))
            let pending = ingredients.filter { !serverIds.contains($0.id) }
            ingredients = pending + rows.map { $0.toIngredient() }
            lastFetchedAt = Date()
            rescheduleNotifications()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Name suggestions (autocomplete)

    /// Up to 5 of the user's own past ingredient names matching `prefix`, most recent first.
    /// RLS + the `user_id` filter mean this can never surface another user's history. Returns
    /// `[]` on error (offline, etc.) rather than throwing — suggestions are a nicety, never
    /// something that should block or interrupt typing.
    func fetchNameSuggestions(matching prefix: String) async -> [IngredientSuggestion] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 2, let userId = getUserId() else { return [] }

        do {
            let rows: [IngredientHistoryRow] = try await client
                .from("ingredient_history")
                .select()
                .eq("user_id", value: userId.uuidString)
                .ilike("name", pattern: "\(trimmed)%")
                .order("last_used_at", ascending: false)
                .limit(5)
                .execute()
                .value

            return rows.map {
                IngredientSuggestion(id: $0.name, name: $0.name, category: Ingredient.Category(rawValue: $0.category) ?? .other)
            }
        } catch {
            return []
        }
    }

    // MARK: - Data Export

    /// Every row in the user's `ingredient_history` — unlike `fetchNameSuggestions`, which filters
    /// by a name prefix and caps at 5 results, this returns the complete history for export.
    func fetchAllIngredientHistory() async -> [(name: String, category: String, useCount: Int, lastUsedAt: Date?, createdAt: Date?)] {
        guard let userId = getUserId() else { return [] }
        do {
            let rows: [IngredientHistoryFullRow] = try await client
                .from("ingredient_history")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("last_used_at", ascending: false)
                .execute()
                .value
            return rows.map { (name: $0.name, category: $0.category, useCount: $0.useCount, lastUsedAt: $0.lastUsedAt, createdAt: $0.createdAt) }
        } catch {
            return []
        }
    }

    // MARK: - Add

    /// Writes a whole Photo Scan batch in one Supabase call instead of N sequential inserts.
    /// Each `BatchScanItem.id` is used directly as the row's `id`, so the temp→server row swap
    /// below is a simple id match, independent of whatever order Supabase returns rows in.
    func addIngredients(_ items: [BatchScanItem]) async {
        guard let userId = getUserId(), !items.isEmpty else { return }

        let tempIngredients = items.map { item in
            Ingredient(
                id: item.id,
                name: item.name.lowercased(),
                amount: item.amountText,
                unitCount: item.unitCount,
                quantityEstimate: item.quantityEstimate,
                quantitySource: .manualEstimate,
                category: item.category,
                location: item.storageLocation,
                expirationDate: item.expirationDate,
                icon: item.icon,
                estimatedUnitCost: item.cost?.unitPriceUsd,
                estimatedTotalCost: item.cost?.totalPriceUsd,
                costUnit: item.cost != nil ? item.costQuantityUnit.unit : nil,
                costSource: item.cost?.source.rawValue
            )
        }
        let tempIds = Set(tempIngredients.map(\.id))

        performOptimistic(
            apply: { ingredients.insert(contentsOf: tempIngredients, at: 0) },
            rollback: { self.ingredients.removeAll { tempIds.contains($0.id) } }
        ) {
            let inserts = items.map { item in
                IngredientInsert(
                    id: item.id,
                    userId: userId,
                    name: item.name.lowercased(),
                    amount: item.amountText,
                    unitCount: item.unitCount,
                    quantityEstimate: item.quantityEstimate.rawValue,
                    quantitySource: Ingredient.QuantitySource.manualEstimate.rawValue,
                    category: item.category.rawValue,
                    location: item.storageLocation.rawValue,
                    expirationDate: item.expirationDate.map { self.formatDate($0) },
                    notes: nil,
                    icon: item.icon,
                    estimatedUnitCost: item.cost?.unitPriceUsd,
                    estimatedTotalCost: item.cost?.totalPriceUsd,
                    costUnit: item.cost != nil ? item.costQuantityUnit.unit : nil,
                    costSource: item.cost?.source.rawValue
                )
            }

            let rows: [IngredientRow] = try await self.client
                .from("ingredients")
                .insert(inserts)
                .select()
                .execute()
                .value

            for row in rows {
                if let index = self.ingredients.firstIndex(where: { $0.id == row.id }) {
                    self.ingredients[index] = row.toIngredient()
                }
            }
            self.rescheduleNotifications()
            self.recordPantryEvents(self.ingredients.filter { tempIds.contains($0.id) }, outcome: .bought)
        }
    }

    // MARK: - Update

    func updateIngredient(
        id: UUID,
        name: String,
        amount: String?,
        unitCount: Int = 1,
        quantityEstimate: Ingredient.QuantityEstimate? = nil,
        quantitySource: Ingredient.QuantitySource? = nil,
        category: Ingredient.Category,
        location: Ingredient.StorageLocation,
        expirationDate: Date?,
        icon: String? = nil,
        estimatedTotalCost: Double? = nil
    ) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let cleanedAmount = amount?.trimmingCharacters(in: .whitespacesAndNewlines)

        let duplicateExists = ingredients.contains {
            $0.id != id && $0.name.lowercased() == cleaned.lowercased()
        }
        guard !duplicateExists else { return }

        guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
        let previous = ingredients[index]

        performOptimistic(
            apply: {
                ingredients[index].name = cleaned.lowercased()
                ingredients[index].amount = cleanedAmount?.isEmpty == true ? nil : cleanedAmount
                ingredients[index].unitCount = unitCount
                ingredients[index].quantityEstimate = quantityEstimate
                ingredients[index].quantitySource = quantitySource
                ingredients[index].category = category
                ingredients[index].location = location
                ingredients[index].expirationDate = expirationDate
                ingredients[index].icon = icon
                if let estimatedTotalCost {
                    ingredients[index].estimatedTotalCost = estimatedTotalCost
                }
            },
            rollback: {
                if let idx = self.ingredients.firstIndex(where: { $0.id == id }) {
                    self.ingredients[idx] = previous
                }
            }
        ) {
            let update = IngredientUpdate(
                name: cleaned.lowercased(),
                amount: cleanedAmount?.isEmpty == true ? nil : cleanedAmount,
                unitCount: unitCount,
                quantityEstimate: quantityEstimate?.rawValue,
                quantitySource: quantitySource?.rawValue,
                category: category.rawValue,
                location: location.rawValue,
                expirationDate: expirationDate.map { self.formatDate($0) },
                notes: self.ingredients[index].notes,
                icon: icon,
                estimatedTotalCost: estimatedTotalCost
            )
            try await self.client
                .from("ingredients")
                .update(update)
                .eq("id", value: id.uuidString)
                .execute()
            self.rescheduleNotifications()
        }
    }

    // MARK: - Confirmed price history

    /// Upserts a user-corrected price into `ingredient_price_history` (`source = 'personal'`), so
    /// the next log of this ingredient resolves from it (tier 1 of the cost cascade) instead of
    /// re-estimating. Fire-and-forget — a failure here never blocks a pantry save.
    func upsertConfirmedPrice(ingredientName: String, unitPrice: Double, unit: String, barcode: String?) async {
        guard let userId = getUserId() else { return }
        let key = ingredientName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty, unitPrice > 0 else { return }

        struct PriceUpsert: Encodable {
            let userId: String
            let ingredientKey: String
            let unitPrice: Double
            let unit: String
            let source: String
            let barcode: String?
            let lastUpdated: String

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case ingredientKey = "ingredient_key"
                case unitPrice = "unit_price"
                case unit, source, barcode
                case lastUpdated = "last_updated"
            }
        }

        let row = PriceUpsert(
            userId: userId.uuidString,
            ingredientKey: key,
            unitPrice: (unitPrice * 100).rounded() / 100,
            unit: unit,
            source: "personal",
            barcode: barcode,
            lastUpdated: ISO8601DateFormatter().string(from: Date())
        )

        do {
            try await client
                .from("ingredient_price_history")
                .upsert(row, onConflict: "user_id,ingredient_key")
                .execute()
        } catch {
            print("upsertConfirmedPrice failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Stats event ledger

    /// Appends `outcome` rows to `pantry_events`, snapshotting each item's category + cost at
    /// event time. Fire-and-forget — a failure here never blocks or rolls back the pantry
    /// mutation that triggered it (mirrors `upsertConfirmedPrice`).
    private func recordPantryEvents(_ ingredients: [Ingredient], outcome: PantryEventOutcome) {
        guard !ingredients.isEmpty else { return }
        let rows = ingredients.map { ingredient in
            PantryEventInsert(
                ingredientId: ingredient.id,
                ingredientName: ingredient.name,
                ingredientKey: ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                category: ingredient.category.rawValue,
                outcome: outcome.rawValue,
                costValue: ingredient.estimatedTotalCost
            )
        }
        Task {
            do {
                try await client.from("pantry_events").insert(rows).execute()
            } catch {
                print("recordPantryEvents(\(outcome.rawValue)) failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Use (update amount or delete)

    func useIngredient(id: UUID, newAmount: String?) {
        guard let newAmount, !newAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            deleteIngredient(id: id, outcome: .used)
            return
        }
        guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
        let previous = ingredients[index]

        performOptimistic(
            apply: {
                ingredients[index].amount = newAmount
                ingredients[index].unitCount = 1
            },
            rollback: {
                if let idx = self.ingredients.firstIndex(where: { $0.id == id }) {
                    self.ingredients[idx] = previous
                }
            }
        ) {
            // Once part of a multi-unit stack has been used, the remaining amount is just a flat
            // quantity, not "N discrete original-sized units" anymore — collapse unit_count back to 1.
            try await self.client
                .from("ingredients")
                .update(UseAmountUpdate(amount: newAmount, unitCount: 1))
                .eq("id", value: id.uuidString)
                .execute()
            self.rescheduleNotifications()
        }
    }

    // MARK: - Delete

    /// `outcome` records why the item left the pantry, for the Stats event ledger — `.used` when
    /// it was consumed (via `useIngredient`'s full-use path or cooking), `.wasted` for any other
    /// removal (the default: a plain delete of a still-good or expired item both read as binned).
    func deleteIngredient(id: UUID, outcome: PantryEventOutcome = .wasted) {
        guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
        let removed = ingredients[index]

        performOptimistic(
            apply: { ingredients.remove(at: index) },
            rollback: { self.ingredients.insert(removed, at: min(index, self.ingredients.count)) }
        ) {
            try await self.client
                .from("ingredients")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            self.rescheduleNotifications()
            self.recordPantryEvents([removed], outcome: outcome)
        }
    }

    func remove(at offsets: IndexSet) {
        let idsToRemove = offsets.map { ingredients[$0].id }
        for id in idsToRemove {
            deleteIngredient(id: id)
        }
    }

    // MARK: - Notifications

    private func rescheduleNotifications() {
        notificationDebounceTask?.cancel()
        notificationDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await ExpirationNotificationScheduler.rescheduleAll(for: ingredients.filter { !$0.dismissed })
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        pantryDateFormatter.string(from: date)
    }
}
