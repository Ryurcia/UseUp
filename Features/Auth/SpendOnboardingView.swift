import SwiftUI

struct SpendOnboardingView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onBack: () -> Void
    var onContinue: () -> Void
    @State private var selectedOption: String?

    private let options = [
        "Under $25",
        "$25 – $75",
        "$75+",
    ]

    var body: some View {
        PrimingQuestionView(
            question: "How much do you spend ordering in per week?",
            options: options,
            onBack: onBack,
            onContinue: {
                onboardingAnswers.spendAnswer = selectedOption
                onContinue()
            },
            selectedOption: $selectedOption
        )
        .onAppear { selectedOption = onboardingAnswers.spendAnswer }
    }
}
