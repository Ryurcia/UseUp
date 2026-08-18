import SwiftUI
import PhosphorSwift

/// Storage-location filter option shared by Pantry's and Generate's filter sheets — both
/// independently declared an identical `fridge`/`freezer`/`pantry` enum.
enum IngredientStorageFilter: CaseIterable, Identifiable {
    case fridge
    case freezer
    case pantry

    var id: String { label }

    var label: String {
        switch self {
        case .fridge: return "Fridge"
        case .freezer: return "Freezer"
        case .pantry: return "Pantry"
        }
    }

    var icon: Image {
        switch self {
        case .fridge: return Ph.doorOpen.regular
        case .freezer: return Ph.snowflake.regular
        case .pantry: return Ph.archive.regular
        }
    }

    func matches(ingredient: Ingredient) -> Bool {
        switch self {
        case .fridge: return ingredient.location == .fridge
        case .freezer: return ingredient.location == .freezer
        case .pantry: return ingredient.location == .pantry
        }
    }
}
