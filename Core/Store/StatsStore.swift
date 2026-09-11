import Foundation
import Supabase

/// One decoded `pantry_events` row. `outcome` is a raw string on the wire; `resolvedOutcome` maps
/// it to the shared `PantryEventOutcome` (nil for an unknown value, which the aggregation skips).
struct PantryEvent: Identifiable {
    let id = UUID()
    let ingredientName: String
    let ingredientKey: String
    let category: Ingredient.Category
    let outcome: PantryEventOutcome
    let costValue: Double?
    let occurredAt: Date
}

@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var events: [PantryEvent] = []
    @Published private(set) var isLoading = false

    var userId: UUID?
    private let client = SupabaseManager.client

    /// Bound how far back `refresh()` pulls — yearly view shows 4 years, so 5 covers it with slack.
    private let windowYears = 5

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    init() {}

    /// Preview/test seam — `PreviewContainer` builds a populated store without a network call.
    init(events: [PantryEvent]) {
        self.events = events
    }

    private struct PantryEventRow: Decodable {
        let ingredientName: String
        let ingredientKey: String
        let category: String
        let outcome: String
        let costValue: Double?
        let occurredAt: Date

        enum CodingKeys: String, CodingKey {
            case ingredientName = "ingredient_name"
            case ingredientKey = "ingredient_key"
            case category, outcome
            case costValue = "cost_value"
            case occurredAt = "occurred_at"
        }

        func toEvent() -> PantryEvent? {
            guard let outcome = PantryEventOutcome(rawValue: outcome) else { return nil }
            return PantryEvent(
                ingredientName: ingredientName,
                ingredientKey: ingredientKey,
                category: Ingredient.Category(rawValue: category) ?? .other,
                outcome: outcome,
                costValue: costValue,
                occurredAt: occurredAt
            )
        }
    }

    private let selectColumns = "ingredient_name,ingredient_key,category,outcome,cost_value,occurred_at"

    func refresh() async {
        guard let userId else { return }
        isLoading = true
        defer { isLoading = false }

        let cutoff = Calendar.current.date(byAdding: .year, value: -windowYears, to: Date()) ?? Date.distantPast

        do {
            let rows: [PantryEventRow] = try await client
                .from("pantry_events")
                .select(selectColumns)
                .eq("user_id", value: userId.uuidString)
                .gte("occurred_at", value: Self.iso8601.string(from: cutoff))
                .order("occurred_at", ascending: false)
                .execute()
                .value
            events = rows.compactMap { $0.toEvent() }
        } catch {
            // Best-effort — keep whatever we last had.
        }
    }

    /// Every event for the user, unwindowed — for the CSV export. Errors resolve to `[]`, matching
    /// `PantryStore.fetchAllIngredientHistory()`.
    func fetchAllPantryEvents() async -> [PantryEvent] {
        guard let userId else { return [] }
        do {
            let rows: [PantryEventRow] = try await client
                .from("pantry_events")
                .select(selectColumns)
                .eq("user_id", value: userId.uuidString)
                .order("occurred_at", ascending: false)
                .execute()
                .value
            return rows.compactMap { $0.toEvent() }
        } catch {
            return []
        }
    }

    func clearForSignOut() {
        events = []
        userId = nil
    }
}
