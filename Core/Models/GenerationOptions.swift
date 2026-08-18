import Foundation

struct GenerationOptions: Hashable {
    enum DietType: String, CaseIterable, Identifiable {
        case any = "Any"
        case vegetarian = "Vegetarian"
        case vegan = "Vegan"
        case pescatarian = "Pescatarian"
        case keto = "Keto"
        case paleo = "Paleo"

        var id: String { rawValue }
    }

    enum DietaryRestriction: String, CaseIterable, Identifiable, Hashable {
        case glutenFree = "Gluten-Free"
        case nutFree = "Nut-Free"
        case dairyFree = "Dairy-Free"
        case soyFree = "Soy-Free"
        case eggFree = "Egg-Free"
        case shellfishFree = "Shellfish-Free"
        case lowSodium = "Low Sodium"

        var id: String { rawValue }
    }

    var dietType: DietType = .any
    var dietaryRestrictions: Set<DietaryRestriction> = []
    var allergies: [String] = []
    var maxTimeMinutes: Int = 30
    var targetCalories: Int? = nil
    var cuisine: Cuisine?
    var skillLevel: Int = 1
    var priorityIngredients: [String] = []
    var diversifyIngredients: Bool = false
}
