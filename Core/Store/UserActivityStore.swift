import Foundation
import Supabase

@MainActor
final class UserActivityStore: ObservableObject {
    @Published var itemsSaved: Int = 0
    @Published var recipesCooked: Int = 0
    @Published var itemsWasted: Int = 0
    @Published var generationsThisWeek: Int = 0
    @Published var nextGenerationResetDate: Date? = nil

    var userId: UUID?
    private let client = SupabaseManager.client

    func logEvent(type: String) {
        guard let userId else { return }

        // Optimistic update
        switch type {
        case "item_saved": itemsSaved += 1
        case "recipe_cooked": recipesCooked += 1
        case "item_wasted": itemsWasted += 1
        case "recipe_generated": generationsThisWeek += 1
        default: break
        }

        Task {
            do {
                try await client
                    .from("user_activity")
                    .insert([
                        "user_id": userId.uuidString,
                        "event_type": type,
                    ])
                    .execute()
            } catch {
                // Rollback
                switch type {
                case "item_saved": itemsSaved = max(0, itemsSaved - 1)
                case "recipe_cooked": recipesCooked = max(0, recipesCooked - 1)
                case "item_wasted": itemsWasted = max(0, itemsWasted - 1)
                case "recipe_generated": generationsThisWeek = max(0, generationsThisWeek - 1)
                default: break
                }
            }
        }
    }

    func fetchStats(since date: Date) async {
        guard let userId else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let dateString = formatter.string(from: date)

        do {
            struct ActivityRow: Decodable {
                let eventType: String

                enum CodingKeys: String, CodingKey {
                    case eventType = "event_type"
                }
            }

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
                switch row.eventType {
                case "item_saved": saved += 1
                case "recipe_cooked": cooked += 1
                case "item_wasted": wasted += 1
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

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let dateString = formatter.string(from: weekAgo)

        do {
            struct ActivityRow: Decodable {
                let eventType: String
                let createdAt: String
                enum CodingKeys: String, CodingKey {
                    case eventType = "event_type"
                    case createdAt = "created_at"
                }
            }

            let rows: [ActivityRow] = try await client
                .from("user_activity")
                .select("event_type, created_at")
                .eq("user_id", value: userId.uuidString)
                .eq("event_type", value: "recipe_generated")
                .gte("created_at", value: dateString)
                .order("created_at", ascending: true)
                .execute()
                .value

            generationsThisWeek = rows.count

            // Compute when the oldest generation in the window will age out (rolling 7-day reset).
            // Supabase returns timestamps with fractional seconds, so try both formatters.
            let fractionalFormatter = ISO8601DateFormatter()
            fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let oldest = rows.first {
                let oldestDate = fractionalFormatter.date(from: oldest.createdAt)
                    ?? formatter.date(from: oldest.createdAt)
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

    /// Human-readable label for when the rolling 7-day generation limit resets.
    /// Returns "tomorrow", "in X days", or the weekday + date for further-out dates.
    func resetLabel(for date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "later today"
        case 1: return "tomorrow"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return "on \(formatter.string(from: date))"
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
