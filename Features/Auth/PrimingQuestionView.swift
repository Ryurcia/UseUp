import SwiftUI

struct PrimingQuestionView: View {
    let question: String
    let options: [String]
    var onBack: () -> Void
    var onContinue: () -> Void
    @Binding var selectedOption: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Sourdough.Spacing.screenMargin) {
                    Text(question)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.display)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Sourdough.Spacing.betweenBlocks)

                    VStack(spacing: Sourdough.Spacing.rowInternals) {
                        ForEach(options, id: \.self) { option in
                            OnboardingOptionCard(label: option, isSelected: selectedOption == option) {
                                selectedOption = option
                            }
                        }
                    }
                    .padding(.top, Sourdough.Spacing.insideChip)
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            VStack(spacing: Sourdough.Spacing.insideChip) {
                Button { onBack() } label: {
                    Text("Back").frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.SecondaryButtonStyle(fullWidth: true))

                Button { onContinue() } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true, isDisabled: selectedOption == nil))
                .disabled(selectedOption == nil)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
    }
}
