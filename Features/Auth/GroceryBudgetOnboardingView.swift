import SwiftUI

struct GroceryBudgetOnboardingView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onContinue: () -> Void
    @State private var selectedOption: PrimingChoice?

    private let options: [PrimingChoice] = [
        .init(label: "Under $50", value: 25),
        .init(label: "$50 – $100", value: 75),
        .init(label: "$100 – $150", value: 125),
        .init(label: "$150+", value: 175),
    ]

    var body: some View {
        PrimingQuestionView(
            question: "How much do you usually spend on groceries per week?",
            options: options,
            onContinue: {
                onboardingAnswers.groceryBudgetChoice = selectedOption
                onContinue()
            },
            selectedOption: $selectedOption
        )
        .onAppear { selectedOption = onboardingAnswers.groceryBudgetChoice }
    }
}
