import SwiftUI

struct SpendOnboardingView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onContinue: () -> Void
    @State private var selectedOption: PrimingChoice?

    private let options: [PrimingChoice] = [
        .init(label: "Under $25", value: 15),
        .init(label: "$25 – $75", value: 50),
        .init(label: "$75+", value: 100),
    ]

    var body: some View {
        PrimingQuestionView(
            question: "How much do you spend ordering in per week?",
            options: options,
            onContinue: {
                onboardingAnswers.spendChoice = selectedOption
                onContinue()
            },
            selectedOption: $selectedOption
        )
        .onAppear { selectedOption = onboardingAnswers.spendChoice }
    }
}
