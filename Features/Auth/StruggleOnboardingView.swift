import SwiftUI

struct StruggleOnboardingView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onContinue: () -> Void
    @State private var selectedOption: String?

    private let options = [
        "Finding recipes with ingredients I already have",
        "Keeping track of my pantry/fridge",
        "Deciding what to cook",
        "Remembering to use ingredients before they expire",
    ]

    var body: some View {
        PrimingQuestionView(
            question: "What do you struggle with the most?",
            options: options,
            onContinue: {
                onboardingAnswers.struggleAnswer = selectedOption
                onContinue()
            },
            selectedOption: $selectedOption
        )
        .onAppear { selectedOption = onboardingAnswers.struggleAnswer }
    }
}
