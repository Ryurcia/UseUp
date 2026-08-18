import Foundation

enum AllergyType: String, CaseIterable, Identifiable, Codable {
    case peanuts   = "Peanuts"
    case treeNuts  = "Tree Nuts"
    case milk      = "Milk"
    case eggs      = "Eggs"
    case wheat     = "Wheat"
    case soy       = "Soy"
    case fish      = "Fish"
    case shellfish = "Shellfish"
    case sesame    = "Sesame"

    var id: String { rawValue }

    var ingredientKeywords: [String] {
        switch self {
        case .peanuts:   return ["peanut", "groundnut"]
        case .treeNuts:  return ["almond", "cashew", "walnut", "pecan", "hazelnut",
                                  "pistachio", "brazil nut", "macadamia", "pine nut"]
        case .milk:      return ["milk", "cream", "cheese", "butter", "yogurt",
                                  "whey", "casein", "dairy", "lactose"]
        case .eggs:      return ["egg"]
        case .wheat:     return ["wheat", "flour", "bread", "pasta", "gluten",
                                  "semolina", "barley", "rye"]
        case .soy:       return ["soy", "tofu", "edamame", "miso", "tempeh", "soya"]
        case .fish:      return ["fish", "salmon", "tuna", "cod", "tilapia", "bass",
                                  "halibut", "anchovy", "sardine", "mackerel", "trout"]
        case .shellfish: return ["shrimp", "crab", "lobster", "clam", "oyster",
                                  "scallop", "mussel", "prawn", "crawfish", "squid"]
        case .sesame:    return ["sesame", "tahini"]
        }
    }

    /// Splits comma-separated free text into individual, trimmed, non-empty allergen strings.
    static func parseCustomAllergens(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
