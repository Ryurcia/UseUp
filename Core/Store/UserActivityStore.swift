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
    @Published var generationsThisWeek: Int = 0
    @Published var nextGenerationResetDate: Date? = nil
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
    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
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
            generationsThisWeek += 1
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
                    generationsThisWeek = max(0, generationsThisWeek - 1)
                    generationsToday = max(0, generationsToday - 1)
                }
            }
        }
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

    func fetchGenerationsThisWeek() async {
        guard let userId else { return }

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let dateString = Self.iso8601.string(from: weekAgo)

        do {
            let rows: [ActivityRow] = try await client
                .from("user_activity")
                .select("event_type, created_at")
                .eq("user_id", value: userId.uuidString)
                .eq("event_type", value: ActivityEventType.recipeGenerated.rawValue)
                .gte("created_at", value: dateString)
                .order("created_at", ascending: true)
                .limit(3)
                .execute()
                .value

            generationsThisWeek = rows.count

            // Compute when the oldest generation in the window will age out (rolling 7-day reset).
            // Supabase returns timestamps with fractional seconds, so try both formatters.
            if let oldest = rows.first, let createdAt = oldest.createdAt {
                let oldestDate = Self.iso8601Fractional.date(from: createdAt)
                    ?? Self.iso8601.date(from: createdAt)
                nextGenerationResetDate = oldestDate.map {
                    Calendar.current.date(byAdding: .day, value: 7, to: $0)
                } ?? nil
            } else {
                nextGenerationResetDate = nil
            }
        } catch {
            // Keep current value on error
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

    /// Human-readable label for when the rolling 7-day generation limit resets.
    /// Returns "tomorrow", "in X days", or the weekday + date for further-out dates.
    func resetLabel(for date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "later today"
        case 1: return "tomorrow"
        default:
            return "on \(Self.weekdayFormatter.string(from: date))"
        }
    }

    func clearForSignOut() {
        itemsSaved = 0
        recipesCooked = 0
        itemsWasted = 0
        generationsThisWeek = 0
        nextGenerationResetDate = nil
        userId = nil
    }
}
