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
        case seafood
        case produce
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
            case .seafood:  return "Seafood"
            case .produce: return "Produce"
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
            case .proteins:   return "🥩"
            case .seafood:    return "🐟"
            case .produce:    return "🥕"
            case .vegetables: return "🥦"
            case .carbs:      return "🍞"
            case .dairy:      return "🥛"
            case .fruits:     return "🍎"
            case .condiments: return "🫙"
            case .other:      return "📦"
            }
        }
    }

    enum QuantityEstimate: String, CaseIterable, Identifiable {
        case little
        case some
        case aLot = "a_lot"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .little: return "Little"
            case .some: return "Some"
            case .aLot: return "A lot"
            }
        }
    }

    enum QuantitySource: String, CaseIterable, Identifiable {
        case manualEstimate = "manual_estimate"
        case manualPrecise = "manual_precise"
        case barcode

        var id: String { rawValue }
    }

    let id: UUID
    var name: String
    var amount: String?
    var unitCount: Int
    var quantityEstimate: QuantityEstimate?
    var quantitySource: QuantitySource?
    var category: Category
    var location: StorageLocation
    var expirationDate: Date?
    var loggedAt: Date
    var notes: String?
    var icon: String?
    var notifReadAt: Date?
    var dismissed: Bool
    /// Cost estimate resolved at log time. `estimatedUnitCost` is per `costUnit`; `estimatedTotalCost`
    /// covers the full logged amount (× `unitCount`). `costSource` is the cascade tier that
    /// supplied the base price (`personal` / `openfoodfacts` / `estimate`). All nil for items
    /// logged before this feature or when resolution failed.
    var estimatedUnitCost: Double?
    var estimatedTotalCost: Double?
    var costUnit: String?
    var costSource: String?
    /// Set once a daily server-side sweep has recorded this item's cost as a `wasted`
    /// `pantry_events` row (because its `expirationDate` passed) — lets `PantryStore.deleteIngredient`
    /// avoid writing a second `wasted` event for the same item when it's later deleted.
    var wastedRecordedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        amount: String? = nil,
        unitCount: Int = 1,
        quantityEstimate: QuantityEstimate? = nil,
        quantitySource: QuantitySource? = nil,
        category: Category = .other,
        location: StorageLocation,
        expirationDate: Date? = nil,
        loggedAt: Date = Date(),
        notes: String? = nil,
        icon: String? = nil,
        notifReadAt: Date? = nil,
        dismissed: Bool = false,
        estimatedUnitCost: Double? = nil,
        estimatedTotalCost: Double? = nil,
        costUnit: String? = nil,
        costSource: String? = nil,
        wastedRecordedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unitCount = unitCount
        self.quantityEstimate = quantityEstimate
        self.quantitySource = quantitySource
        self.category = category
        self.location = location
        self.expirationDate = expirationDate
        self.loggedAt = loggedAt
        self.notes = notes
        self.icon = icon
        self.notifReadAt = notifReadAt
        self.dismissed = dismissed
        self.estimatedUnitCost = estimatedUnitCost
        self.estimatedTotalCost = estimatedTotalCost
        self.costUnit = costUnit
        self.costSource = costSource
        self.wastedRecordedAt = wastedRecordedAt
    }

    /// Total on hand, accounting for `unitCount` (5 x "227 g" -> "1135 g") -- what "enough for a
    /// recipe" / "available to use" checks should compare against, not `amount` alone, which is
    /// only one unit's size. Falls back to `amount` unchanged when unitCount is 1 or unparseable.
    var totalAmount: String? {
        guard let amount, unitCount != 1, let parsed = QuantityConverter.parse(amount) else { return amount }
        return "\(QuantityConverter.formatQuantity(parsed.value * Double(unitCount))) \(parsed.unit.label)"
    }

    /// Amount text with unit count folded in when it's worth showing (`"5 × 227 g"`), unchanged when
    /// there's only one unit (`"227 g"`) — the count is only useful context once there's more than one.
    var displayAmount: String? {
        guard let amount, unitCount > 1 else { return amount }
        return "\(unitCount) × \(amount)"
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

extension Ingredient.Category {
    /// Deliberately biased toward the shorter end of realistic ranges: a default that's too
    /// short just causes an early "check on this" nudge, but one that's too long can mask real
    /// spoilage — the wrong direction to err on for a feature whose whole point is surfacing
    /// spoilage risk. Freezer values aren't given the same downward bias, since running past a
    /// freezer estimate is a quality issue, not a spoilage-detection failure.
    ///
    // TODO(product): illustrative shelf-life estimates, not validated food-safety data. Used
    // only to pre-fill a default expiration date the user can freely adjust.
    func defaultShelfLifeDays(in location: Ingredient.StorageLocation) -> Int {
        switch (self, location) {
        case (.proteins, .freezer): return 90
        case (.proteins, _): return 2
        case (.seafood, .freezer): return 60
        case (.seafood, _): return 2
        case (.dairy, .freezer): return 60
        case (.dairy, _): return 7
        case (.produce, .freezer), (.vegetables, .freezer), (.fruits, .freezer): return 240
        case (.produce, .pantry): return 4
        case (.produce, _): return 5
        case (.vegetables, .pantry): return 10
        case (.vegetables, _): return 5
        case (.fruits, _): return 7
        case (.carbs, .pantry): return 60
        case (.carbs, .freezer): return 90
        case (.carbs, _): return 5
        case (.condiments, .pantry): return 180
        case (.condiments, _): return 60
        case (.other, .pantry): return 21
        case (.other, .freezer): return 90
        case (.other, _): return 5
        }
    }

    /// Heuristic minimum cook-time thresholds, named and adjustable — NOT a food-safety-certified
    /// standard, just a "this is probably undercooked" nudge. `.proteins` covers both red meat and
    /// poultry (the category isn't split further), so it's biased to poultry's stricter minimum
    /// since poultry needs more thorough cooking than red meat, which can safely be eaten less well
    /// done.
    // TODO(product): illustrative thresholds, not validated food-safety data. Tune freely.
    enum MinimumCookTime {
        static let proteinsMinutes = 20
        static let seafoodMinutes = 8
    }

    var minimumSafeCookMinutes: Int? {
        switch self {
        case .proteins: return MinimumCookTime.proteinsMinutes
        case .seafood: return MinimumCookTime.seafoodMinutes
        default: return nil
        }
    }
}
