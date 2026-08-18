import SwiftUI

struct DietaryPreferenceOnboardingView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var selectedDiet: GenerationOptions.DietType = .any

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Sourdough.Spacing.screenMargin) {
                    Text("What's Your Diet?")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.display)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Sourdough.Spacing.betweenBlocks)

                    Text("We'll use this as your default when generating recipes. You can always change it later.")
                        .sourdoughTextStyle(.body)
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals), GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals)],
                        spacing: Sourdough.Spacing.rowInternals
                    ) {
                        ForEach(GenerationOptions.DietType.allCases) { dietType in
                            OnboardingOptionCard(label: dietType.rawValue, isSelected: selectedDiet == dietType) {
                                selectedDiet = dietType
                            }
                        }
                    }
                    .padding(.top, Sourdough.Spacing.insideChip)
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            // Pinned bottom buttons
            VStack(spacing: Sourdough.Spacing.insideChip) {
                Button {
                    onBack()
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.SecondaryButtonStyle(fullWidth: true))

                Button {
                    onboardingAnswers.dietType = selectedDiet
                    onContinue()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true))
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
        .onAppear { selectedDiet = onboardingAnswers.dietType }
    }
}
