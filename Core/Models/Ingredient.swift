import Foundation

struct Ingredient: Identifiable, Hashable {
    enum StorageLocation: String, CaseIterable, Identifiable {
        case pantry
        case fridge
        case freezer

        var id: String { rawValue }

        var title: String {
            switch self {
            case .pantry: return "Pantry"
            case .fridge: return "Fridge"
            case .freezer: return "Freezer"
            }
        }
    }

    enum Category: String, CaseIterable, Identifiable {
        case proteins
        case vegetables
        case carbs
        case dairy
        case fruits
        case condiments
        case other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .proteins: return "Proteins"
            case .vegetables: return "Vegetables"
            case .carbs: return "Carbs"
            case .dairy: return "Dairy"
            case .fruits: return "Fruits"
            case .condiments: return "Condiments"
            case .other: return "Other"
            }
        }

        var icon: String {
            switch self {
            case .proteins: return "fish"
            case .vegetables: return "leaf"
            case .carbs: return "birthday.cake"
            case .dairy: return "cup.and.saucer"
            case .fruits: return "basket"
            case .condiments: return "drop"
            case .other: return "ellipsis.circle"
            }
        }
    }

    let id: UUID
    var name: String
    var amount: String?
    var category: Category
    var location: StorageLocation
    var expirationDate: Date?
    var loggedAt: Date
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        amount: String? = nil,
        category: Category = .other,
        location: StorageLocation,
        expirationDate: Date? = nil,
        loggedAt: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.location = location
        self.expirationDate = expirationDate
        self.loggedAt = loggedAt
        self.notes = notes
    }

    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Calendar.current.startOfDay(for: Date())
    }

    var isExpiringSoon: Bool {
        guard let days = daysUntilExpiration else { return false }
        return days >= 0 && days <= 3
    }

    var daysUntilExpiration: Int? {
        guard let expirationDate else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: expirationDate)
        return Calendar.current.dateComponents([.day], from: start, to: end).day
    }
}
