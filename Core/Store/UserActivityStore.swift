import Foundation
import Supabase

/// `user_activity.event_type` values — a typed alternative to passing raw strings to `logEvent`,
/// so a typo is caught at compile time instead of silently falling into `default: break`.
enum ActivityEventType: String {
    case itemSaved = "item_saved"
    case recipeCooked = "recipe_cooked"
    case itemWasted = "item_wasted"
    case recipeGenerated = "recipe_generated"
}

/// Decodable row for the `user_activity` table — shared by every fetch method below rather than
/// each declaring its own local copy. `createdAt` is only populated when the query selects it.
private struct ActivityRow: Decodable {
    let eventType: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case createdAt = "created_at"
    }
}

@MainActor
final class UserActivityStore: ObservableObject {
    @Published var itemsSaved: Int = 0
    @Published var recipesCooked: Int = 0
    @Published var itemsWasted: Int = 0
    @Published var generationsToday: Int = 0
    @Published var nextDailyResetDate: Date? = nil

    var userId: UUID?
    private let client = SupabaseManager.client

    // Shared formatters — ISO8601DateFormatter init is expensive, so reuse instances.
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    func logEvent(type: ActivityEventType) {
        guard let userId else { return }

        // Optimistic update
        switch type {
        case .itemSaved: itemsSaved += 1
        case .recipeCooked: recipesCooked += 1
        case .itemWasted: itemsWasted += 1
        case .recipeGenerated:
            generationsToday += 1
        }

        Task {
            do {
                try await client
                    .from("user_activity")
                    .insert([
                        "user_id": userId.uuidString,
                        "event_type": type.rawValue,
                    ])
                    .execute()
            } catch {
                // Rollback
                switch type {
                case .itemSaved: itemsSaved = max(0, itemsSaved - 1)
                case .recipeCooked: recipesCooked = max(0, recipesCooked - 1)
                case .itemWasted: itemsWasted = max(0, itemsWasted - 1)
                case .recipeGenerated:
                    generationsToday = max(0, generationsToday - 1)
                }
            }
        }
    }

    /// The `recipe_generated` row is written server-side by the `generate-recipes` edge function,
    /// so the client doesn't `logEvent` for it. Bump the counter optimistically for instant UI,
    /// then reconcile against the table.
    func noteRecipeGeneratedRemotely() {
        generationsToday += 1
        Task { await fetchGenerationsToday() }
    }

    func fetchStats(since date: Date) async {
        guard let userId else { return }

        let dateString = Self.iso8601.string(from: date)

        do {
            let rows: [ActivityRow] = try await client
                .from("user_activity")
                .select("event_type")
                .eq("user_id", value: userId.uuidString)
                .gte("created_at", value: dateString)
                .execute()
                .value

            var saved = 0
            var cooked = 0
            var wasted = 0
            for row in rows {
                switch ActivityEventType(rawValue: row.eventType) {
                case .itemSaved: saved += 1
                case .recipeCooked: cooked += 1
                case .itemWasted: wasted += 1
                default: break
                }
            }
            itemsSaved = saved
            recipesCooked = cooked
            itemsWasted = wasted
        } catch {
            // Keep current values on error
        }
    }

    func fetchGenerationsToday() async {
        guard let userId else { return }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let dateString = Self.iso8601.string(from: startOfDay)

        do {
            let rows: [ActivityRow] = try await client
                .from("user_activity")
                .select("event_type")
                .eq("user_id", value: userId.uuidString)
                .eq("event_type", value: ActivityEventType.recipeGenerated.rawValue)
                .gte("created_at", value: dateString)
                .limit(5)
                .execute()
                .value

            generationsToday = rows.count
            nextDailyResetDate = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)
        } catch {
            // Keep current value on error
        }
    }

    /// Every activity row for the current user, unfiltered by date/type/limit — used for data
    /// export. `fetchStats(since:)` and `fetchGenerationsToday()` are windowed for their specific
    /// dashboard purpose; neither returns the complete history.
    func fetchAllActivity() async -> [(eventType: String, createdAt: String?)] {
        guard let userId else { return [] }
        do {
            let rows: [ActivityRow] = try await client
                .from("user_activity")
                .select("event_type, created_at")
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows.map { (eventType: $0.eventType, createdAt: $0.createdAt) }
        } catch {
            return []
        }
    }

    func clearForSignOut() {
        itemsSaved = 0
        recipesCooked = 0
        itemsWasted = 0
        generationsToday = 0
        nextDailyResetDate = nil
        userId = nil
    }
}
