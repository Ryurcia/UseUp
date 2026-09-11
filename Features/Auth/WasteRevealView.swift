import SwiftUI

struct WasteRevealView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onContinue: () -> Void
    @State private var animatedValue: Double = 0

    private var moneyThrownAway: Double { onboardingAnswers.moneyThrownAway ?? 0 }

    /// 9 bags, last 3 binned — "nearly 1 in 3 bags". Illustrative, matches the source design.
    private let bagPattern: [Bool] = [false, false, false, false, false, false, true, true, true]

    /// Illustrative — the app doesn't track a per-item waste breakdown yet. Matches the source
    /// design's example list.
    private let usualSuspects: [(glyph: String, name: String, cost: String, tint: Color)] = [
        ("🥬", "Salad greens", "$34/mo", Sourdough.Ramp.sage100),
        ("🥛", "Milk & yogurt", "$28/mo", Sourdough.Ramp.honey100),
        ("🍞", "Bread", "$19/mo", Sourdough.Ramp.terracotta100),
    ]

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
                        VStack(alignment: .leading, spacing: Sourdough.Spacing.screenMargin) {
                            Text("And here's what's going in the trash.")
                                .foregroundStyle(Sourdough.Colors.mutedInk)
                                .sourdoughTextStyle(.body)

                            Sourdough.CountUpText(value: animatedValue, format: { $0.asWholeDollarString })
                                .sourdoughTextStyle(.heroXL)
                                .foregroundStyle(Sourdough.Colors.destructive)

                            Text("a month in groceries you paid for and never ate.")
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.title2)
                        }

                        wasteCard
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.vertical, Sourdough.Spacing.betweenBlocks)
                    .frame(minHeight: geo.size.height, alignment: Alignment(horizontal: .leading, vertical: .center))
                }
            }

            Button { onContinue() } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true))
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
        .onAppear {
            Sourdough.animatedCountUp(to: moneyThrownAway) { animatedValue = $0 }
        }
    }

    private var wasteCard: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
            VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(bagPattern.enumerated()), id: \.offset) { index, binned in
                        Sourdough.AnimatedBarV(
                            fill: binned ? Sourdough.Colors.action : Sourdough.Ramp.sage100,
                            border: binned ? Sourdough.Colors.actionInk : Sourdough.Ramp.sage200,
                            height: binned ? 30 : 40 + CGFloat(index % 3) * 4,
                            delay: 0.9 + Double(index) * 0.045
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 48, alignment: .bottom)

                HStack(spacing: Sourdough.Spacing.betweenBlocks) {
                    legendSwatch(color: Sourdough.Ramp.sage100, border: Sourdough.Ramp.sage200, label: "Eaten")
                    legendSwatch(color: Sourdough.Colors.action, border: Sourdough.Colors.actionInk, label: "Binned")
                }
            }

            VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                Text("Usual suspects")
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.sectionHead)

                VStack(spacing: Sourdough.Spacing.rowInternals) {
                    ForEach(Array(usualSuspects.enumerated()), id: \.offset) { _, suspect in
                        HStack(spacing: Sourdough.Spacing.rowInternals) {
                            RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous)
                                .fill(suspect.tint)
                                .frame(width: 30, height: 30)
                                .overlay(Text(suspect.glyph))
                            Text(suspect.name)
                                .sourdoughTextStyle(.rowTitle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(suspect.cost)
                                .foregroundStyle(Sourdough.Colors.actionInk)
                                .sourdoughTextStyle(.numeric)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sourdough.Spacing.screenMargin)
        .background(Sourdough.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
        .sourdoughElevation(.lifted, cornerRadius: Sourdough.Radius.hero)
    }

    private func legendSwatch(color: Color, border: Color, label: String) -> some View {
        HStack(spacing: Sourdough.Spacing.iconToLabel) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .overlay(RoundedRectangle(cornerRadius: 2, style: .continuous).stroke(border, lineWidth: 1))
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.caption)
        }
    }
}
