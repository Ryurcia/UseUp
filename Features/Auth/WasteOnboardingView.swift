import SwiftUI

struct WasteOnboardingView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onBack: () -> Void
    var onContinue: () -> Void
    @State private var selectedOption: String?

    private let options = [
        "Less than 10%",
        "10–25%",
        "25–50%",
        "50% or more",
    ]

    var body: some View {
        PrimingQuestionView(
            question: "How much of your groceries go to waste?",
            options: options,
            onBack: onBack,
            onContinue: {
                onboardingAnswers.wasteAnswer = selectedOption
                onContinue()
            },
            selectedOption: $selectedOption
        )
        .onAppear { selectedOption = onboardingAnswers.wasteAnswer }
    }
}
