import Foundation

@MainActor
final class OnboardingAnswers: ObservableObject {
    @Published var preferredName: String = ""
    @Published var dietType: GenerationOptions.DietType = .any
    @Published var restrictions: Set<GenerationOptions.DietaryRestriction> = []
    @Published var allergies: Set<AllergyType> = []
    @Published var customAllergyText: String = ""
    @Published var cookingSkillLevel: Int?

    // In-session only (never read by AppSession.saveOnboardingAnswers, never persisted to Supabase).
    @Published var struggleAnswer: String?
    @Published var spendChoice: PrimingChoice?
    @Published var groceryBudgetChoice: PrimingChoice?
    @Published var wasteChoice: PrimingChoice?
    @Published var goalAnswer: String?

    // Derived from the choices above — always recomputed from source, so reveal/pitch screens
    // stay correct if the user goes back and changes an earlier answer.
    var monthlyOrderInSpend: Double? { spendChoice.map { $0.value * 4.33 } }
    var groceryMonthlySpend: Double? { groceryBudgetChoice.map { $0.value * 4.33 } }
    var wastePercent: Double? { wasteChoice?.value }
    var moneyThrownAway: Double? {
        guard let groceryMonthlySpend, let wastePercent else { return nil }
        return groceryMonthlySpend * wastePercent / 100
    }
}
