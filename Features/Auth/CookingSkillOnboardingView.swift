import SwiftUI
import PhosphorSwift

struct CookingSkillOnboardingView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onContinue: () -> Void

    @State private var selectedLevel: Int? = nil

    private let options: [(level: Int, label: String, icon: Image)] = [
        (1, "I'd rather order in", Ph.smileyBlank.regular),
        (2, "I can cook a decent meal", Ph.cookingPot.regular),
        (3, "Just call me Gordon Ramsay", Ph.star.fill),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Sourdough.Spacing.screenMargin) {
                    Text("How Well Do You Cook?")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.display)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, Sourdough.Spacing.betweenBlocks)

                    Text("We'll tailor recipe complexity to match your skills.")
                        .sourdoughTextStyle(.body)
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: Sourdough.Spacing.rowInternals) {
                        ForEach(options, id: \.level) { option in
                            let isSelected = selectedLevel == option.level
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedLevel = option.level
                                }
                            } label: {
                                HStack(spacing: Sourdough.Spacing.rowInternals) {
                                    option.icon
                                        .frame(width: 20, height: 20)
                                        .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)
                                        .frame(width: 32)

                                    Text(option.label)
                                        .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.ink)
                                        .sourdoughTextStyle(.rowTitle)

                                    Spacer()

                                    Ph.checkCircle.fill
                                        .frame(width: 20, height: 20)
                                        .foregroundStyle(Sourdough.Colors.onAction)
                                        .opacity(isSelected ? 1 : 0)
                                }
                                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                                .padding(.vertical, 20)
                                .frame(minHeight: 72)
                                .background(
                                    isSelected
                                        ? Sourdough.Ramp.sage500
                                        : Sourdough.Colors.sunken
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous)
                                        .stroke(
                                            isSelected
                                                ? Color.clear
                                                : Sourdough.Colors.interactiveBorder,
                                            lineWidth: 1
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, Sourdough.Spacing.insideChip)
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            Button {
                onboardingAnswers.cookingSkillLevel = selectedLevel ?? 1
                onContinue()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true, isDisabled: selectedLevel == nil))
            .disabled(selectedLevel == nil)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
        .onAppear { selectedLevel = onboardingAnswers.cookingSkillLevel }
    }
}
