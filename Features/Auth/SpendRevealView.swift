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

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                page { damageBlock }
                    .onAppear {
                        Sourdough.animatedCountUp(to: monthlySpend) { animatedValue = $0 }
                    }
                    .tag(0)

                page { yearlyBlock }
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
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.vertical, Sourdough.Spacing.betweenBlocks)
                    .frame(minHeight: geo.size.height, alignment: Alignment(horizontal: .center, vertical: .center))
            }
        }
    }

    private var damageBlock: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("Here's the damage")
                .foregroundStyle(Sourdough.Colors.actionInk)
                .sourdoughTextStyle(.sectionHead)
                .multilineTextAlignment(.center)

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
                .multilineTextAlignment(.center)
                .padding(.top, Sourdough.Spacing.screenMargin)
        }
    }

    private var yearlyBlock: some View {
        VStack(alignment: .center, spacing: 0) {
            Text("And over a year")
                .foregroundStyle(Sourdough.Colors.actionInk)
                .sourdoughTextStyle(.sectionHead)
                .multilineTextAlignment(.center)

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
            .multilineTextAlignment(.center)
            .padding(.top, Sourdough.Spacing.screenMargin)
        }
    }
}
