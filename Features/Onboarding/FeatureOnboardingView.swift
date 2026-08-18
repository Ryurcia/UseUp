import SwiftUI

#Preview("Feature Onboarding") {
    PreviewContainer(authenticated: false) {
        FeatureOnboardingView()
    }
}

struct FeatureOnboardingView: View {
    @EnvironmentObject private var session: AppSession
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "PANTRY_MOCKUP",
            title: "Keep Track of Your Pantry",
            description: "Log what you have and know when it expires."
        ),
        OnboardingPage(
            imageName: "RECIPES_MOCKUP",
            title: "Generate Recipes",
            description: "Get recipes using stuff you already have"
        ),
        OnboardingPage(
            imageName: "COMMUNITY_MOCKUP",
            title: "Discover & Share",
            description: "Browse for recipes shared by the community or share your own recipes"
        ),
    ]

    private var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            // Step progress bar
            HStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(0..<pages.count, id: \.self) { index in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Sourdough.Colors.interactiveBorder)
                        Capsule()
                            .fill(Sourdough.Colors.action)
                            .scaleEffect(x: index <= currentPage ? 1 : 0, anchor: .leading)
                            .animation(DS.Motion.easeDefault, value: currentPage)
                    }
                    .frame(height: 4)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.insideChip)

            ZStack {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    if currentPage == index {
                        OnboardingPageView(page: page)
                    }
                }
            }
            .animation(DS.Motion.easeDefault, value: currentPage)
        }
        .background(Sourdough.Colors.canvas)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Sourdough.Colors.canvas.opacity(0), Sourdough.Colors.canvas],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 32)
                .allowsHitTesting(false)

                Button {
                    if isLastPage {
                        session.completeFeatureOnboarding()
                    } else {
                        withAnimation(DS.Motion.easeDefault) {
                            currentPage += 1
                        }
                    }
                } label: {
                    Text(isLastPage ? "Start Cooking" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true))
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.insideChip)
                .padding(.bottom, Sourdough.Spacing.aboveSectionHead)
                .background(Sourdough.Colors.canvas)
            }
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            if let uiImage = UIImage(named: page.imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.top, Sourdough.Spacing.aboveSectionHead)
                    .frame(maxWidth: .infinity, maxHeight: 480)
                    .background {
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Sourdough.Colors.action.opacity(0.5),
                                        Sourdough.Ramp.sage500.opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 10,
                                    endRadius: 180
                                )
                            )
                            .blur(radius: 55)
                            .scaleEffect(x: 1.0, y: 0.75)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 28)
                    .animation(.timingCurve(0, 0, 0.2, 1, duration: 0.5).delay(0.08), value: appeared)
            }

            Spacer()

            VStack(spacing: Sourdough.Spacing.rowInternals) {
                Text(page.title)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.display)
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 28)
                    .animation(.timingCurve(0, 0, 0.2, 1, duration: 0.5).delay(0.2), value: appeared)

                Text(page.description)
                    .sourdoughTextStyle(.body)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 28)
                    .animation(.timingCurve(0, 0, 0.2, 1, duration: 0.5).delay(0.3), value: appeared)
            }
            .padding(.top, Sourdough.Spacing.aboveSectionHead)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.aboveSectionHead)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Sourdough.Colors.canvas)
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
    }
}

private struct OnboardingPage {
    let imageName: String
    let title: String
    let description: String
}
