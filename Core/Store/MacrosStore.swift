import Foundation

@MainActor
final class MacrosStore: ObservableObject {
    @Published private(set) var macroGoals: Macros?
    @Published private(set) var macroProfile: MacroProfile?
    @Published private(set) var entries: [MacroEntry] = []

    var hasCompletedSetup: Bool { macroGoals != nil }

    init() {
        seedDummyEntries()
    }

    func completeSetup(profile: MacroProfile) {
        macroProfile = profile
        macroGoals = profile.recommendedMacros
    }

    func updateGoals(_ macros: Macros) {
        macroGoals = macros
    }

    // MARK: - Entries

    func logEntry(name: String, servings: Double, macrosPerServing: Macros, mealType: MealType) {
        let entry = MacroEntry(
            name: name,
            servings: servings,
            macrosPerServing: macrosPerServing,
            mealType: mealType
        )
        entries.append(entry)
    }

    func entriesForMeal(_ meal: MealType) -> [MacroEntry] {
        let calendar = Calendar.current
        return entries.filter { entry in
            entry.mealType == meal && calendar.isDateInToday(entry.date)
        }
    }

    var todayTotals: Macros {
        let calendar = Calendar.current
        let todayEntries = entries.filter { calendar.isDateInToday($0.date) }
        return todayEntries.reduce(Macros(calories: 0, proteinG: 0, carbsG: 0, fatG: 0)) { result, entry in
            let total = entry.totalMacros
            return Macros(
                calories: result.calories + total.calories,
                proteinG: result.proteinG + total.proteinG,
                carbsG: result.carbsG + total.carbsG,
                fatG: result.fatG + total.fatG
            )
        }
    }

    // MARK: - Seed Data

    private func seedDummyEntries() {
        let today = Date()

        entries = [
            MacroEntry(name: "Greek Yogurt", servings: 1, macrosPerServing: Macros(calories: 130, proteinG: 15, carbsG: 8, fatG: 4), mealType: .breakfast, date: today),
            MacroEntry(name: "Granola (1/2 cup)", servings: 1, macrosPerServing: Macros(calories: 150, proteinG: 4, carbsG: 22, fatG: 6), mealType: .breakfast, date: today),
            MacroEntry(name: "Grilled Chicken Breast", servings: 1, macrosPerServing: Macros(calories: 320, proteinG: 42, carbsG: 0, fatG: 8), mealType: .lunch, date: today),
            MacroEntry(name: "Brown Rice (1 cup)", servings: 1, macrosPerServing: Macros(calories: 215, proteinG: 5, carbsG: 45, fatG: 2), mealType: .lunch, date: today),
            MacroEntry(name: "Mixed Salad w/ Olive Oil", servings: 1, macrosPerServing: Macros(calories: 185, proteinG: 4, carbsG: 12, fatG: 14), mealType: .dinner, date: today),
            MacroEntry(name: "Salmon Fillet", servings: 1, macrosPerServing: Macros(calories: 350, proteinG: 28, carbsG: 0, fatG: 22), mealType: .dinner, date: today),
            MacroEntry(name: "Apple", servings: 1, macrosPerServing: Macros(calories: 95, proteinG: 0, carbsG: 25, fatG: 0), mealType: .snacks, date: today),
            MacroEntry(name: "Almonds (1 oz)", servings: 1, macrosPerServing: Macros(calories: 165, proteinG: 6, carbsG: 6, fatG: 14), mealType: .snacks, date: today),
        ]
    }
}
