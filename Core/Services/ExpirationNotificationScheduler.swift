import UserNotifications

enum ExpirationNotificationScheduler {

    static func rescheduleAll(for ingredients: [Ingredient]) async {
        let expiring = ingredients.filter { ingredient in
            guard let days = ingredient.daysUntilExpiration else { return false }
            return days >= 0 && days <= 3
        }

        await scheduleNotifications(for: expiring)
        refreshSuggestedRecipeCache(for: expiring)
    }

    /// Schedules expiration-reminder and recipe-suggestion notifications, sharing iOS's 64-pending-notification
    /// budget between both kinds (sorted soonest-first) so the two don't silently starve each other.
    private static func scheduleNotifications(for expiring: [Ingredient]) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        var allRequests: [(fireDate: Date, request: UNNotificationRequest)] = []

        let expiringItemsEnabled = (UserDefaults.standard.object(forKey: "expiringItemsNotificationsEnabled") as? Bool) ?? true

        // Group by the day the reminder actually FIRES (not by expiration date) so ingredients
        // with different expiration dates whose daily reminder cascades happen to land on the
        // same morning are merged into one notification instead of arriving separately.
        var byFireOffset: [Int: [(ingredient: Ingredient, daysRemaining: Int)]] = [:]
        for ingredient in expiring {
            guard let expirationDate = ingredient.expirationDate,
                  let daysUntil = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: expirationDate)).day,
                  daysUntil >= 0
            else { continue }
            for fireOffset in 0...daysUntil {
                byFireOffset[fireOffset, default: []].append((ingredient, daysUntil - fireOffset))
            }
        }

        for (fireOffset, items) in byFireOffset where expiringItemsEnabled {
            guard let fireDate = calendar.date(byAdding: .day, value: fireOffset, to: today) else { continue }

            let content = UNMutableNotificationContent()
            content.sound = .default

            if items.count == 1 {
                let (ingredient, daysRemaining) = items[0]
                switch daysRemaining {
                case 0:
                    content.title = "Your \(ingredient.name) expires today"
                case 1:
                    content.title = "Your \(ingredient.name) expires tomorrow"
                default:
                    content.title = "Your \(ingredient.name) expires in \(daysRemaining) days"
                }
            } else {
                let uniqueDays = Set(items.map(\.daysRemaining))
                if uniqueDays.count == 1, let daysRemaining = uniqueDays.first {
                    switch daysRemaining {
                    case 0:
                        content.title = "You have \(items.count) things expiring today"
                    case 1:
                        content.title = "You have \(items.count) things expiring tomorrow"
                    default:
                        content.title = "You have \(items.count) things about to go bad in \(daysRemaining) days"
                    }
                    content.body = items.map { $0.ingredient.name }.joined(separator: ", ")
                } else {
                    // Mixed urgency (different expiration dates, same fire day) — annotate each.
                    content.title = "You have \(items.count) items expiring soon"
                    content.body = items
                        .sorted { $0.daysRemaining < $1.daysRemaining }
                        .map { entry -> String in
                            switch entry.daysRemaining {
                            case 0: return "\(entry.ingredient.name) (today)"
                            case 1: return "\(entry.ingredient.name) (tomorrow)"
                            default: return "\(entry.ingredient.name) (\(entry.daysRemaining)d)"
                            }
                        }
                        .joined(separator: ", ")
                }
            }

            var dateComponents = calendar.dateComponents([.year, .month, .day], from: fireDate)
            dateComponents.hour = 9
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let identifier = "expiration-\(dateFormatter.string(from: fireDate))"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

            allRequests.append((fireDate: fireDate, request: request))
        }

        let recipeSuggestionsEnabled = (UserDefaults.standard.object(forKey: "recipeSuggestionsEnabled") as? Bool) ?? true
        if recipeSuggestionsEnabled {
            var byFireDay: [Date: [Ingredient]] = [:]
            for ingredient in expiring {
                guard let expirationDate = ingredient.expirationDate else { continue }
                let daysUntil = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: expirationDate)).day ?? 0
                let fireDay = daysUntil > 0 ? calendar.startOfDay(for: expirationDate) : today
                byFireDay[fireDay, default: []].append(ingredient)
            }

            for (fireDay, ingredientsForDay) in byFireDay {
                let content = UNMutableNotificationContent()
                content.sound = .default

                if ingredientsForDay.count == 1 {
                    content.title = "Use your \(ingredientsForDay[0].name) before it expires!"
                    content.body = "Tap for recipe ideas to use it up."
                } else {
                    content.title = "Use up \(ingredientsForDay.count) ingredients before they expire!"
                    content.body = ingredientsForDay.map(\.name).joined(separator: ", ") + " — tap for recipe ideas."
                }

                var dateComponents = calendar.dateComponents([.year, .month, .day], from: fireDay)
                dateComponents.hour = 18
                dateComponents.minute = 0

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let identifier = "recipe-suggestion-\(dateFormatter.string(from: fireDay))"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                allRequests.append((fireDate: fireDay, request: request))
            }
        }

        // Both notification kinds share iOS's system-wide 64-pending cap; sort combined so the
        // soonest-firing reminders (of either kind) win the budget instead of expiration reminders
        // silently starving recipe suggestions (or vice versa) whenever the total exceeds 64.
        allRequests.sort { $0.fireDate < $1.fireDate }

        center.removeAllPendingNotificationRequests()
        for item in allRequests.prefix(64) {
            try? await center.add(item.request)
        }
    }

    /// Pre-computes recipe suggestions for expiring ingredients (non-blocking), independent of
    /// notification-authorization status so suggestions stay available in-app even if the user
    /// hasn't granted push permission.
    private static func refreshSuggestedRecipeCache(for expiring: [Ingredient]) {
        Task { @MainActor in
            if let recipes = SavedRecipesStore.shared?.communityRecipes, !recipes.isEmpty {
                SuggestedRecipeCache.shared.refresh(expiringIngredients: expiring, allRecipes: recipes)
            }
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
