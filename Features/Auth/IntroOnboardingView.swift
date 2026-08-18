import SwiftUI
import PhosphorSwift

struct IntroOnboardingView: View {
    var onBack: () -> Void
    var onContinue: () -> Void

    @State private var showHeadline = false
    @State private var showSubtitle = false

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

                Spacer()
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.insideChip)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
                ZStack {
                    RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                        .fill(Sourdough.Ramp.terracotta100)
                        .frame(width: 64, height: 64)
                    Ph.magicWand.regular
                        .frame(width: 26, height: 26)
                        .foregroundStyle(Sourdough.Colors.actionInk)
                }

                VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                    Text("Let's Personalize Your Experience")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.display)
                        .opacity(showHeadline ? 1 : 0)
                        .offset(y: showHeadline ? 0 : 16)

                    Text("We'll ask a few quick questions about you, your diet, restrictions, and cooking skill so we can tailor recipes just for you.")
                        .sourdoughTextStyle(.body)
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .opacity(showSubtitle ? 1 : 0)
                        .offset(y: showSubtitle ? 0 : 16)
                }

                Label {
                    Text("Takes about 60 seconds")
                } icon: {
                    Ph.clock.regular
                        .frame(width: 13, height: 13)
                }
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.caption)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)

            Spacer(minLength: 0)

            Button {
                onContinue()
            } label: {
                Text("Sounds Good")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true))
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { showHeadline = true }
            withAnimation(.easeOut(duration: 0.9).delay(0.35)) { showSubtitle = true }
        }
    }
}
