import SwiftUI

struct SpendRevealView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onContinue: () -> Void
    @State private var animatedValue: Double = 0
    @State private var animatedYearly: Double = 0
    @State private var animatedDinnerCount: Double = 0
    @State private var currentPage = 0
    private let pageCount = 2

    private var monthlySpend: Double { onboardingAnswers.monthlyOrderInSpend ?? 0 }
    private var yearlySpend: Double { monthlySpend * 12 }

    // TODO(product): placeholder assumption, not validated against real order data. Confirm
    // before this claim ships broadly.
    private let averageDinnerPrice = 15.0
    private var dinnerCount: Int { Int((yearlySpend / averageDinnerPrice).rounded()) }

    /// Illustrative — the app doesn't collect a delivery/fees/snacks split. Matches the source
    /// design's example breakdown.
    private let breakdown: [(label: String, percent: Int, color: Color)] = [
        ("Delivery apps", 69, Sourdough.Colors.action),
        ("Fees & tips", 22, Sourdough.Ramp.terracotta400),
        ("Late-night snacks", 9, Sourdough.Ramp.honey300),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                page { damageBlock }
                    .onAppear {
                        Sourdough.animatedCountUp(to: monthlySpend) { animatedValue = $0 }
                    }
                    .tag(0)

                page {
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.underTitle) {
                        yearlyBlock
                        breakdownCard
                    }
                }
                .onAppear {
                    Sourdough.animatedCountUp(to: yearlySpend) { animatedYearly = $0 }
                    // Smooth (non-haptic) count-up — a second overlapping haptic-tick
                    // generator would buzz rather than read as one clean moment.
                    withAnimation(.easeOut(duration: 1.0)) {
                        animatedDinnerCount = Double(dinnerCount)
                    }
                }
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Sourdough.Colors.action : Sourdough.Colors.hairline)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, Sourdough.Spacing.rowInternals)

            Button { onContinue() } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true, isDisabled: currentPage < pageCount - 1))
            .disabled(currentPage < pageCount - 1)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
    }

    @ViewBuilder
    private func page<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.vertical, Sourdough.Spacing.betweenBlocks)
                    .frame(minHeight: geo.size.height, alignment: Alignment(horizontal: .leading, vertical: .center))
            }
        }
    }

    private var damageBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Here's the damage")
                .foregroundStyle(Sourdough.Colors.actionInk)
                .sourdoughTextStyle(.sectionHead)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("$")
                    .sourdoughTextStyle(.heroXL)
                    .foregroundStyle(Sourdough.Colors.action)
                Sourdough.CountUpText(value: animatedValue, format: { $0.asWholeNumberString })
                    .sourdoughTextStyle(.heroXL)
                    .foregroundStyle(Sourdough.Colors.ink)
            }
            .padding(.top, Sourdough.Spacing.screenMargin)

            Text("a month you spend ordering in.")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.display)
                .padding(.top, Sourdough.Spacing.screenMargin)
        }
    }

    private var yearlyBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("And over a year")
                .foregroundStyle(Sourdough.Colors.actionInk)
                .sourdoughTextStyle(.sectionHead)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("$")
                    .sourdoughTextStyle(.hero)
                    .foregroundStyle(Sourdough.Colors.action)
                Sourdough.CountUpText(value: animatedYearly, format: { $0.asWholeNumberString })
                    .sourdoughTextStyle(.hero)
                    .foregroundStyle(Sourdough.Colors.ink)
            }
            .padding(.top, Sourdough.Spacing.screenMargin)

            Sourdough.CountUpText(value: animatedDinnerCount) { dinners in
                Text("about ")
                + Text("\(Int(dinners.rounded())) dinners").fontWeight(.bold).foregroundColor(Sourdough.Colors.actionInk)
                + Text(" you paid delivery prices for.")
            }
            .sourdoughTextStyle(.display)
            .padding(.top, Sourdough.Spacing.screenMargin)
        }
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            Text("Where it goes")
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.sectionHead)

            VStack(spacing: Sourdough.Spacing.rowInternals) {
                ForEach(Array(breakdown.enumerated()), id: \.offset) { index, row in
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.iconToLabel) {
                        HStack {
                            Text(row.label)
                                .sourdoughTextStyle(.rowTitle)
                            Spacer()
                            Text("\(row.percent)%")
                                .sourdoughTextStyle(.numeric)
                        }
                        Sourdough.AnimatedBarH(
                            fraction: Double(row.percent) / 100,
                            fill: row.color,
                            delay: 0.9 + Double(index) * 0.09
                        )
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
}
