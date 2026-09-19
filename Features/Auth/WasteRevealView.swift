import SwiftUI

struct WasteRevealView: View {
    @EnvironmentObject private var onboardingAnswers: OnboardingAnswers
    var onContinue: () -> Void
    @State private var animatedValue: Double = 0

    private var moneyThrownAway: Double { onboardingAnswers.moneyThrownAway ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .center, spacing: Sourdough.Spacing.screenMargin) {
                        Text("And here's what's going in the trash.")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.body)
                            .multilineTextAlignment(.center)

                        Sourdough.CountUpText(value: animatedValue, format: { $0.asWholeDollarString })
                            .sourdoughTextStyle(.heroXL)
                            .foregroundStyle(Sourdough.Colors.destructive)

                        Text("a month in groceries you paid for and never ate.")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.title2)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.vertical, Sourdough.Spacing.betweenBlocks)
                    .frame(minHeight: geo.size.height, alignment: Alignment(horizontal: .center, vertical: .center))
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
}
