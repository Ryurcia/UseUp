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
    @Published var spendAnswer: String?
    @Published var wasteAnswer: String?
    @Published var goalAnswer: String?
}
