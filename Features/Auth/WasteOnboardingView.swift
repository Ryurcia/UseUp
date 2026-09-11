import SwiftUI

struct WasteOnboardingView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onContinue: () -> Void
    @State private var selectedOption: PrimingChoice?

    private let options: [PrimingChoice] = [
        .init(label: "Less than 10%", value: 5),
        .init(label: "10–25%", value: 17.5),
        .init(label: "25–50%", value: 37.5),
        .init(label: "50% or more", value: 60),
    ]

    var body: some View {
        PrimingQuestionView(
            question: "How much of your groceries go to waste?",
            options: options,
            onContinue: {
                onboardingAnswers.wasteChoice = selectedOption
                onContinue()
            },
            selectedOption: $selectedOption
        )
        .onAppear { selectedOption = onboardingAnswers.wasteChoice }
    }
}
