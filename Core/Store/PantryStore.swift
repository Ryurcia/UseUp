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
    let category: String
    let location: String
    let expirationDate: String?
    let loggedAt: Date?
    let notes: String?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, amount, category, location
        case expirationDate = "expiration_date"
        case loggedAt = "logged_at"
        case notes, icon
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
            category: cat,
            location: loc,
            expirationDate: expDate,
            loggedAt: loggedAt ?? Date(),
            notes: notes,
            icon: icon
        )
    }
}

/// Insert/update payload — no `id` (server generates), no read-only timestamps.
private struct IngredientInsert: Encodable {
    let userId: UUID
    let name: String
    let amount: String?
    let category: String
    let location: String
    let expirationDate: String?
    let notes: String?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name, amount, category, location
        case expirationDate = "expiration_date"
        case notes, icon
    }
}

private struct IngredientUpdate: Encodable {
    let name: String
    let amount: String?
    let category: String
    let location: String
    let expirationDate: String?
    let notes: String?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case name, amount, category, location
        case expirationDate = "expiration_date"
        case notes, icon
    }
}

@MainActor
final class PantryStore: ObservableObject {
    static weak var shared: PantryStore?

    @Published private(set) var ingredients: [Ingredient] = []
    @Published private(set) var isLoading = false
    @Published var error: String?
    @Published var dismissedIngredientIds: Set<UUID> = [] {
        didSet { saveDismissedIds() }
    }
    @Published var notifReadTimestamps: [String: Date] = [:]

    var userId: UUID?
    private var lastFetchedAt: Date?
    private let client = SupabaseManager.client
    private var notificationDebounceTask: Task<Void, Never>?

    private static let dismissedIdsKey = "dismissedIngredientIds"
    private static let readTimestampsKey = "notif_readTimestamps"
    private let autoHideInterval: TimeInterval = 3 * 24 * 3600

    init() {
        loadDismissedIds()
        loadReadTimestamps()
        PantryStore.shared = self
    }

    private func saveDismissedIds() {
        UserDefaults.standard.set(dismissedIngredientIds.map(\.uuidString), forKey: Self.dismissedIdsKey)
    }

    private func loadDismissedIds() {
        guard let stored = UserDefaults.standard.stringArray(forKey: Self.dismissedIdsKey) else { return }
        dismissedIngredientIds = Set(stored.compactMap(UUID.init))
    }

    func markNotificationRead(_ id: String) {
        notifReadTimestamps[id] = Date()
        saveReadTimestamps()
    }

    func markAllNotificationsRead(ids: [String]) {
        let now = Date()
        for id in ids { notifReadTimestamps[id] = now }
        saveReadTimestamps()
    }

    func dismissNotification(for ingredientId: UUID) {
        dismissedIngredientIds.insert(ingredientId)
        rescheduleNotifications()
    }

    /// Dated, non-dismissed ingredients that are expired or expiring within `days` — the single
    /// source of truth for "expiring soon" eligibility, shared by the notification bell badge and
    /// the full notification list so they never disagree on which items qualify.
    func expiringAlertCandidates(withinDays days: Int = 7) -> [Ingredient] {
        ingredients.filter { ingredient in
            guard ingredient.expirationDate != nil else { return false }
            guard !dismissedIngredientIds.contains(ingredient.id) else { return false }
            if ingredient.isExpired { return true }
            guard let daysUntil = ingredient.daysUntilExpiration else { return false }
            return daysUntil <= days
        }
    }

    private func saveReadTimestamps() {
        let raw = notifReadTimestamps.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(raw, forKey: Self.readTimestampsKey)
    }

    private func loadReadTimestamps() {
        let now = Date()
        let purgeCutoff = now.addingTimeInterval(-7 * 24 * 3600)
        let hideCutoff = now.addingTimeInterval(-autoHideInterval)
        var result: [String: Date] = [:]
        if let raw = UserDefaults.standard.dictionary(forKey: Self.readTimestampsKey) as? [String: Double] {
            result = raw.mapValues { Date(timeIntervalSince1970: $0) }.filter { $0.value > purgeCutoff }
        }
        if let oldIds = UserDefaults.standard.stringArray(forKey: "notif_readIds") {
            for id in oldIds where result[id] == nil { result[id] = hideCutoff }
            UserDefaults.standard.removeObject(forKey: "notif_readIds")
        }
        notifReadTimestamps = result
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
        UserDefaults.standard.removeObject(forKey: Self.dismissedIdsKey)
        dismissedIngredientIds = []
        UserDefaults.standard.removeObject(forKey: Self.readTimestampsKey)
        notifReadTimestamps = [:]
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

    // MARK: - Add

    func addIngredient(
        name: String,
        amount: String?,
        category: Ingredient.Category,
        location: Ingredient.StorageLocation,
        expirationDate: Date?,
        icon: String? = nil,
        force: Bool = false
    ) {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let cleanedAmount = amount?.trimmingCharacters(in: .whitespacesAndNewlines)

        let exists = ingredients.contains { $0.name.lowercased() == cleaned.lowercased() }
        guard !exists || force else { return }

        let tempIngredient = Ingredient(
            name: cleaned.lowercased(),
            amount: cleanedAmount?.isEmpty == true ? nil : cleanedAmount,
            category: category,
            location: location,
            expirationDate: expirationDate,
            icon: icon
        )

        performOptimistic(
            apply: { ingredients.insert(tempIngredient, at: 0) },
            rollback: { self.ingredients.removeAll { $0.id == tempIngredient.id } }
        ) {
            guard let userId = self.getUserId() else {
                self.ingredients.removeAll { $0.id == tempIngredient.id }
                return
            }

            let insert = IngredientInsert(
                userId: userId,
                name: cleaned.lowercased(),
                amount: cleanedAmount?.isEmpty == true ? nil : cleanedAmount,
                category: category.rawValue,
                location: location.rawValue,
                expirationDate: expirationDate.map { self.formatDate($0) },
                notes: nil,
                icon: icon
            )

            let rows: [IngredientRow] = try await self.client
                .from("ingredients")
                .insert(insert)
                .select()
                .execute()
                .value

            if let row = rows.first,
               let index = self.ingredients.firstIndex(where: { $0.id == tempIngredient.id }) {
                self.ingredients[index] = row.toIngredient()
            }
            self.rescheduleNotifications()
        }
    }

    // MARK: - Update

    func updateIngredient(
        id: UUID,
        name: String,
        amount: String?,
        category: Ingredient.Category,
        location: Ingredient.StorageLocation,
        expirationDate: Date?,
        icon: String? = nil
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
                ingredients[index].category = category
                ingredients[index].location = location
                ingredients[index].expirationDate = expirationDate
                ingredients[index].icon = icon
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
                category: category.rawValue,
                location: location.rawValue,
                expirationDate: expirationDate.map { self.formatDate($0) },
                notes: self.ingredients[index].notes,
                icon: icon
            )
            try await self.client
                .from("ingredients")
                .update(update)
                .eq("id", value: id.uuidString)
                .execute()
            self.rescheduleNotifications()
        }
    }

    // MARK: - Use (update amount or delete)

    func useIngredient(id: UUID, newAmount: String?) {
        guard let newAmount, !newAmount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            deleteIngredient(id: id)
            return
        }
        guard let index = ingredients.firstIndex(where: { $0.id == id }) else { return }
        let previous = ingredients[index]

        performOptimistic(
            apply: { ingredients[index].amount = newAmount },
            rollback: {
                if let idx = self.ingredients.firstIndex(where: { $0.id == id }) {
                    self.ingredients[idx] = previous
                }
            }
        ) {
            try await self.client
                .from("ingredients")
                .update(["amount": newAmount])
                .eq("id", value: id.uuidString)
                .execute()
            self.rescheduleNotifications()
        }
    }

    // MARK: - Delete

    func deleteIngredient(id: UUID) {
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
            await ExpirationNotificationScheduler.rescheduleAll(for: ingredients.filter { !dismissedIngredientIds.contains($0.id) })
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        pantryDateFormatter.string(from: date)
    }
}
