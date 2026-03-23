import UserNotifications

enum ExpirationNotificationScheduler {

    static func rescheduleAll(for ingredients: [Ingredient]) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        center.removeAllPendingNotificationRequests()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let expiring = ingredients.filter { ingredient in
            guard let days = ingredient.daysUntilExpiration else { return false }
            return days >= 0 && days <= 4
        }

        guard !expiring.isEmpty else { return }

        let grouped = Dictionary(grouping: expiring) { ingredient in
            calendar.startOfDay(for: ingredient.expirationDate!)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"

        var allRequests: [(fireDate: Date, request: UNNotificationRequest)] = []

        for (expirationDate, ingredientsForDate) in grouped {
            let daysUntil = calendar.dateComponents([.day], from: today, to: expirationDate).day ?? 0

            for reminderOffset in 0...daysUntil {
                let fireDate = calendar.date(byAdding: .day, value: reminderOffset, to: today)!
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

        allRequests.sort { $0.fireDate < $1.fireDate }

        for item in allRequests.prefix(64) {
            try? await center.add(item.request)
        }
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
