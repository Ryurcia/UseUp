import SwiftUI

#Preview("Get Started") {
    PreviewContainer(authenticated: false) {
        NavigationStack {
            GetStartedView()
        }
    }
}

struct GetStartedView: View {
    @State private var showingSignUp = false
    private let signUpSlideAnimation = DS.Motion.easeOut

    var body: some View {
        GeometryReader { proxy in
            let safeBottom = proxy.safeAreaInsets.bottom

            HStack(spacing: 0) {
                landingScreen(safeBottom: safeBottom, width: proxy.size.width)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                signUpScreen()
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .offset(x: showingSignUp ? -proxy.size.width : 0)
            .animation(signUpSlideAnimation, value: showingSignUp)
        }
        .background(DS.ColorToken.bgSecondary)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func landingScreen(safeBottom: CGFloat, width: CGFloat) -> some View {
        ZStack {
            Image("splash")
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
                                DS.ColorToken.primary.opacity(0.55),
                                DS.ColorToken.primary.opacity(0.35),
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

            VStack(spacing: DS.Spacing.space4) {
                Text("UseUp")
                    .font(.custom("CalSans-Regular", size: 48))
                    .kerning(0)
                    .foregroundStyle(DS.ColorToken.primary)

                Text("Let's Make Something Great")
                    .font(.custom("CalSans-Regular", size: 20))
                    .kerning(0)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                withAnimation(signUpSlideAnimation) {
                    showingSignUp = true
                }
            } label: {
                Text("Start Cooking")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(size: .lg, fullWidth: true))
            .frame(maxWidth: width * 0.9)
            .padding(.bottom, max(safeBottom + DS.Spacing.space4, DS.Spacing.space8))
            }
        }
    }

    private func signUpScreen() -> some View {
        ZStack {
            AuthView(onBack: {
                withAnimation(signUpSlideAnimation) {
                    showingSignUp = false
                }
            })
        }
    }
}
