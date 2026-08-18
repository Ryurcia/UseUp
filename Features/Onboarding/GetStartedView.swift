import SwiftUI

#Preview("Get Started") {
    PreviewContainer(authenticated: false) {
        NavigationStack {
            GetStartedView()
        }
    }
}

struct GetStartedView: View {
    @EnvironmentObject private var session: AppSession
    @State private var showingOnboarding = false
    @State private var showingSignIn = false

    var body: some View {
        GeometryReader { proxy in
            landingScreen(safeBottom: proxy.safeAreaInsets.bottom, width: proxy.size.width)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Sourdough.Colors.sunken)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showingOnboarding) {
            PreSignupOnboardingContainerView()
        }
        .fullScreenCover(isPresented: $showingSignIn) {
            SignInView()
                .environmentObject(session)
        }
    }

    private func landingScreen(safeBottom: CGFloat, width: CGFloat) -> some View {
        ZStack {
            Image("GetStarted")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()
            Color.black.opacity(0.60)
                .ignoresSafeArea()

            // Holographic glow blob — bottom right
            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Sourdough.Colors.heroAccentOnDark.opacity(0.55),
                                Sourdough.Colors.heroAccentOnDark.opacity(0.35),
                                Color.cyan.opacity(0.12),
                                .clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                    .frame(width: 320, height: 260)
                    .blur(radius: 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .offset(x: 60, y: 60)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Sourdough.Spacing.screenMargin) {
                Text("UseUp")
                    .foregroundStyle(Sourdough.Colors.heroAccentOnDark)
                    .sourdoughTextStyle(.display)

                Text("Let's Make Something Great")
                    .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                    .sourdoughTextStyle(.title2)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: Sourdough.Spacing.rowInternals) {
                Button {
                    showingOnboarding = true
                } label: {
                    Text("Start Cooking")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(Sourdough.PrimaryButtonStyle(fullWidth: true))
                .frame(maxWidth: width * 0.9)

                Button {
                    showingSignIn = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(Sourdough.Colors.heroMetaOnDark)
                        Text("Log In")
                            .foregroundStyle(Sourdough.Colors.heroAccentOnDark)
                            .fontWeight(.semibold)
                    }
                    .sourdoughTextStyle(.subhead)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, max(safeBottom + Sourdough.Spacing.screenMargin, Sourdough.Spacing.aboveSectionHead))
            }
        }
    }
}
