import SwiftUI
import PhosphorSwift

struct PreferencesPreviewOnboardingView: View {
    var onBack: () -> Void
    var onSkip: () -> Void
    var onContinue: () -> Void

    private let rows: [(icon: Image, title: String, subtitle: String)] = [
        (Ph.forkKnife.regular, "Your Diet", "Omnivore, vegetarian, vegan..."),
        (Ph.prohibit.regular, "Allergies & Restrictions", "We'll hide anything you can't eat"),
        (Ph.chartBar.fill, "Cooking Skill", "So steps match your comfort level"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Ph.caretLeft.regular
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .frame(width: 40, height: 40)
                        .background(Sourdough.Colors.sunken)
                        .clipShape(Circle())
                }
                .buttonStyle(AuthBackButtonStyle())
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.insideChip)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                        Text("Three Questions.\nBetter Recipes.")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.display)

                        Text("Answer these once and we'll tune every suggestion to your kitchen.")
                            .sourdoughTextStyle(.body)
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                    }
                    .padding(.top, Sourdough.Spacing.betweenBlocks)

                    VStack(spacing: Sourdough.Spacing.rowInternals) {
                        ForEach(rows, id: \.title) { row in
                            HStack(spacing: Sourdough.Spacing.rowInternals) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                                        .fill(Sourdough.Ramp.terracotta100)
                                        .frame(width: 48, height: 48)
                                    row.icon
                                        .frame(width: 18, height: 18)
                                        .foregroundStyle(Sourdough.Colors.actionInk)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.title)
                                        .foregroundStyle(Sourdough.Colors.ink)
                                        .sourdoughTextStyle(.rowTitle)
                                    Text(row.subtitle)
                                        .sourdoughTextStyle(.subhead)
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(Sourdough.Spacing.screenMargin)
                            .background(Sourdough.Colors.sunken)
                            .overlay(
                                RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous)
                                    .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            VStack(spacing: Sourdough.Spacing.insideChip) {
                Button {
                    onContinue()
                } label: {
                    Text("Sounds Good")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true))

                Button("Skip For Now", action: onSkip)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.subhead)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)

                Text("You can change any of this later in Settings.")
                    .foregroundStyle(Sourdough.Colors.faintInk)
                    .sourdoughTextStyle(.caption)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
    }
}
