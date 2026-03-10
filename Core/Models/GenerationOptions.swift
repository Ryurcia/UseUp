import Foundation

struct GenerationOptions: Hashable {
    enum DietaryPreference: String, CaseIterable, Identifiable {
        case any = "Any"
        case vegetarian = "Vegetarian"
        case vegan = "Vegan"

        var id: String { rawValue }
    }

    var dietaryPreference: DietaryPreference = .any
    var maxTimeMinutes: Int = 30
    var cuisine: Cuisine?
}
