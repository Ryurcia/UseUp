import Foundation

struct MacroProfile {
    enum BiologicalSex: String, CaseIterable {
        case male = "Male"
        case female = "Female"
    }

    enum Goal: String, CaseIterable {
        case buildMuscle = "Build Muscle"
        case maintain = "Maintain"
        case loseFat = "Lose Fat"
        case loseWeight = "Lose Weight"

        var calorieAdjustment: Double {
            switch self {
            case .buildMuscle: 1.10
            case .maintain: 1.0
            case .loseFat: 0.85
            case .loseWeight: 0.75
            }
        }

        /// Protein / Carbs / Fat percentages of adjusted calories.
        var macroSplit: (protein: Double, carbs: Double, fat: Double) {
            switch self {
            case .buildMuscle: (0.30, 0.40, 0.30)
            case .maintain:    (0.25, 0.45, 0.30)
            case .loseFat:     (0.35, 0.35, 0.30)
            case .loseWeight:  (0.30, 0.40, 0.30)
            }
        }

        var subtitle: String {
            switch self {
            case .buildMuscle: "Calorie surplus, high protein"
            case .maintain: "Stay at your current weight"
            case .loseFat: "Preserve muscle, cut fat"
            case .loseWeight: "Calorie deficit to drop pounds"
            }
        }

        var icon: String {
            switch self {
            case .buildMuscle: "dumbbell.fill"
            case .maintain: "equal.circle.fill"
            case .loseFat: "flame.fill"
            case .loseWeight: "arrow.down.circle.fill"
            }
        }
    }

    enum ActivityLevel: String, CaseIterable {
        case sedentary = "Sedentary"
        case lightlyActive = "Lightly Active"
        case moderatelyActive = "Moderately Active"
        case veryActive = "Very Active"

        var multiplier: Double {
            switch self {
            case .sedentary: 1.2
            case .lightlyActive: 1.375
            case .moderatelyActive: 1.55
            case .veryActive: 1.725
            }
        }

        var subtitle: String {
            switch self {
            case .sedentary: "Little or no exercise"
            case .lightlyActive: "Light exercise 1–3 days/week"
            case .moderatelyActive: "Moderate exercise 3–5 days/week"
            case .veryActive: "Hard exercise 6–7 days/week"
            }
        }

        var icon: String {
            switch self {
            case .sedentary: "figure.stand"
            case .lightlyActive: "figure.walk"
            case .moderatelyActive: "figure.run"
            case .veryActive: "figure.highintensity.intervaltraining"
            }
        }
    }

    var sex: BiologicalSex
    var age: Int
    var heightCM: Double
    var weightKG: Double
    var activityLevel: ActivityLevel
    var goal: Goal

    /// Basal Metabolic Rate using Mifflin-St Jeor equation.
    var bmr: Double {
        let base = (10 * weightKG) + (6.25 * heightCM) - (5 * Double(age))
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    /// Total Daily Energy Expenditure.
    var tdee: Double {
        bmr * activityLevel.multiplier
    }

    /// Recommended macros adjusted for the user's goal.
    var recommendedMacros: Macros {
        let adjustedCal = tdee * goal.calorieAdjustment
        let split = goal.macroSplit
        let cal = Int(adjustedCal.rounded())
        let proteinG = Int((adjustedCal * split.protein / 4).rounded(toNearest: 5))
        let carbsG = Int((adjustedCal * split.carbs / 4).rounded(toNearest: 5))
        let fatG = Int((adjustedCal * split.fat / 9).rounded(toNearest: 5))
        return Macros(calories: cal, proteinG: proteinG, carbsG: carbsG, fatG: fatG)
    }
}

private extension Double {
    func rounded(toNearest n: Double) -> Double {
        (self / n).rounded() * n
    }
}
