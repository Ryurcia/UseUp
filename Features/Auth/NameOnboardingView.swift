import SwiftUI

struct NameOnboardingView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Sourdough.Spacing.screenMargin) {
                    Text("What Should We Call You?")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.display)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Sourdough.Spacing.betweenBlocks)

                    Text("We'd love to know what to call you — first name, nickname, whatever feels right.")
                        .sourdoughTextStyle(.body)
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("Your name", text: $name)
                        .focused($isNameFocused)
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.body)
                        .padding(.horizontal, Sourdough.Spacing.rowInternals)
                        .frame(height: 52)
                        .background(Sourdough.Colors.sunken)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                        .padding(.top, Sourdough.Spacing.insideChip)
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            VStack(spacing: Sourdough.Spacing.insideChip) {
                Button { onBack() } label: {
                    Text("Back").frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.SecondaryButtonStyle(fullWidth: true))

                Button {
                    onboardingAnswers.preferredName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    onContinue()
                } label: {
                    Text("Continue").frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true, isDisabled: !canContinue))
                .disabled(!canContinue)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
        .onAppear {
            name = onboardingAnswers.preferredName
            isNameFocused = true
        }
    }
}
