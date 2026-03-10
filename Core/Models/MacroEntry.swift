import Foundation

enum MealType: String, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snacks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snacks: "Snacks"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.fill"
        case .snacks: "cup.and.saucer.fill"
        }
    }
}

struct MacroEntry: Identifiable {
    let id: UUID
    let name: String
    let servings: Double
    let macrosPerServing: Macros
    let mealType: MealType
    let date: Date

    init(
        id: UUID = UUID(),
        name: String,
        servings: Double,
        macrosPerServing: Macros,
        mealType: MealType,
        date: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.servings = servings
        self.macrosPerServing = macrosPerServing
        self.mealType = mealType
        self.date = date
    }

    var totalMacros: Macros {
        Macros(
            calories: Int(round(Double(macrosPerServing.calories) * servings)),
            proteinG: Int(round(Double(macrosPerServing.proteinG) * servings)),
            carbsG: Int(round(Double(macrosPerServing.carbsG) * servings)),
            fatG: Int(round(Double(macrosPerServing.fatG) * servings))
        )
    }
}
