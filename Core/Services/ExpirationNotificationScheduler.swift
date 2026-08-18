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

        var grouped: [Date: [Ingredient]] = [:]
        for ingredient in expiring {
            guard let date = ingredient.expirationDate else { continue }
            let key = calendar.startOfDay(for: date)
            grouped[key, default: []].append(ingredient)
        }

        var allRequests: [(fireDate: Date, request: UNNotificationRequest)] = []

        for (expirationDate, ingredientsForDate) in grouped {
            guard let daysUntil = calendar.dateComponents([.day], from: today, to: expirationDate).day else { continue }

            for reminderOffset in 0...daysUntil {
                guard let fireDate = calendar.date(byAdding: .day, value: reminderOffset, to: today) else { continue }
                let daysRemaining = daysUntil - reminderOffset

                let content = UNMutableNotificationContent()
                content.sound = .default

                if ingredientsForDate.count == 1 {
                    let name = ingredientsForDate[0].name
                    switch daysRemaining {
                    case 0:
                        content.title = "Your \(name) expires today"
                    case 1:
                        content.title = "Your \(name) expires tomorrow"
                    default:
                        content.title = "Your \(name) expires in \(daysRemaining) days"
                    }
                } else {
                    let count = ingredientsForDate.count
                    switch daysRemaining {
                    case 0:
                        content.title = "You have \(count) things expiring today"
                    case 1:
                        content.title = "You have \(count) things expiring tomorrow"
                    default:
                        content.title = "You have \(count) things about to go bad in \(daysRemaining) days"
                    }
                    content.body = ingredientsForDate.map(\.name).joined(separator: ", ")
                }

                var dateComponents = calendar.dateComponents([.year, .month, .day], from: fireDate)
                dateComponents.hour = 9
                dateComponents.minute = 0

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let identifier = "expiration-\(dateFormatter.string(from: fireDate))-\(dateFormatter.string(from: expirationDate))"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                allRequests.append((fireDate: fireDate, request: request))
            }
        }

        let recipeSuggestionsEnabled = (UserDefaults.standard.object(forKey: "recipeSuggestionsEnabled") as? Bool) ?? true
        if recipeSuggestionsEnabled {
            for ingredient in expiring {
                guard let expirationDate = ingredient.expirationDate else { continue }
                let daysUntil = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: expirationDate)).day ?? 0
                let fireDay = daysUntil > 0 ? expirationDate : Date()

                let content = UNMutableNotificationContent()
                content.sound = .default
                content.title = "Use your \(ingredient.name) before it expires!"
                content.body = "Tap for recipe ideas to use it up."

                var dateComponents = calendar.dateComponents([.year, .month, .day], from: fireDay)
                dateComponents.hour = 18
                dateComponents.minute = 0

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let identifier = "recipe-suggestion-\(ingredient.id.uuidString)"
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
