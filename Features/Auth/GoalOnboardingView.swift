import SwiftUI

struct GoalOnboardingView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onBack: () -> Void
    var onContinue: () -> Void
    @State private var selectedOption: String?

    private let options = [
        "Delicious recipes I can easily cook",
        "Reduce waste and use up all my ingredients",
        "Save money and cook instead of ordering in",
        "Stay organized with my inventory",
    ]

    var body: some View {
        PrimingQuestionView(
            question: "What do you want to get out of this app?",
            options: options,
            onBack: onBack,
            onContinue: {
                onboardingAnswers.goalAnswer = selectedOption
                onContinue()
            },
            selectedOption: $selectedOption
        )
        .onAppear { selectedOption = onboardingAnswers.goalAnswer }
    }
}
