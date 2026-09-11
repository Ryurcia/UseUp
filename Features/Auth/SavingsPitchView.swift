import SwiftUI

struct SavingsPitchView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onContinue: () -> Void
    @State private var animatedTotal: Double = 0

    // TODO(product): placeholder assumptions, not validated against real user data. Confirm
    // before this claim ships broadly.
    private let orderInSavingsRate = 0.5
    private let wasteSavingsRate = 0.7

    private var monthlySpend: Double { onboardingAnswers.monthlyOrderInSpend ?? 0 }
    private var reducedSpend: Double { monthlySpend * (1 - orderInSavingsRate) }
    private var orderInSavings: Double { monthlySpend * orderInSavingsRate }
    private var moneyThrownAway: Double { onboardingAnswers.moneyThrownAway ?? 0 }
    private var wasteSavings: Double { moneyThrownAway * wasteSavingsRate }
    private var totalMonthlySavings: Double { orderInSavings + wasteSavings }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
                        Text("Here's what Use Up changes.")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.display)

                        statCard(
                            headline: "We can cut your spend down to \(reducedSpend.asWholeDollarString)/month",
                            subcopy: "was \(monthlySpend.asWholeDollarString)/month ordering in",
                            savingsFraction: orderInSavingsRate,
                            delay: 0.1
                        )

                        statCard(
                            headline: "We can cut your food waste down \(Int(wasteSavingsRate * 100))%",
                            subcopy: "that's \(wasteSavings.asWholeDollarString)/month back in your pocket",
                            savingsFraction: wasteSavingsRate,
                            delay: 0.25
                        )

                        VStack(alignment: .leading, spacing: Sourdough.Spacing.screenMargin) {
                            Text("USE UP COULD SAVE YOU")
                                .foregroundStyle(Sourdough.Colors.mutedInk)
                                .sourdoughTextStyle(.sectionHead)
                

                            Sourdough.CountUpText(value: animatedTotal, format: { $0.asWholeDollarString })
                                .foregroundStyle(Sourdough.Colors.fresh.label)
                                .sourdoughTextStyle(.hero)

                            Text("a month")
                                .foregroundStyle(Sourdough.Colors.mutedInk)
                                .sourdoughTextStyle(.body)
                        }
                        .padding(.top, Sourdough.Spacing.betweenBlocks)
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
            Sourdough.animatedCountUp(to: totalMonthlySavings) { animatedTotal = $0 }
        }
    }

    @ViewBuilder
    private func statCard(headline: String, subcopy: String, savingsFraction: Double, delay: Double) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.screenMargin) {
            VStack(alignment: .leading, spacing: Sourdough.Spacing.iconToLabel) {
                Text(headline)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.title2)
                Text(subcopy)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.subhead)
            }

            GeometryReader { geo in
                HStack(spacing: 3) {
                    Sourdough.AnimatedBarH(
                        fraction: 1,
                        fill: Sourdough.Ramp.sage500,
                        track: .clear,
                        height: 5,
                        delay: delay
                    )
                    .frame(width: (geo.size.width - 3) * savingsFraction)

                    Sourdough.AnimatedBarH(
                        fraction: 1,
                        fill: Sourdough.Ramp.linen300,
                        track: .clear,
                        height: 5,
                        delay: delay + 0.09
                    )
                    .frame(width: (geo.size.width - 3) * (1 - savingsFraction))
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sourdough.Spacing.screenMargin)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous)
                .stroke(Sourdough.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
    }
}
