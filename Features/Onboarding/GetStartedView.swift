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
                landingScreen(safeBottom: safeBottom)
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

    private func landingScreen(safeBottom: CGFloat) -> some View {
        ZStack {
            FloatingEmojisBackground()

            VStack(spacing: 0) {
            Spacer()

            VStack(spacing: DS.Spacing.space4) {
                Text("UseUp")
                    .font(.custom("CalSans-Regular", size: 48))
                    .kerning(0)
                    .foregroundStyle(DS.ColorToken.primary)

                Text("What's Left In Your Fridge?\nLet's Make Something Great")
                    .font(.custom("CalSans-Regular", size: 28))
                    .kerning(0)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Text("Just tell us what you have - we'll do the thinking.")
                    .appTextStyle(.bodySM)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }

            Spacer()

            Button {
                withAnimation(signUpSlideAnimation) {
                    showingSignUp = true
                }
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(size: .lg, fullWidth: true))
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.bottom, max(safeBottom + DS.Spacing.space4, DS.Spacing.space8))
            }
        }
    }

    // MARK: - Floating Emojis

    private struct FloatingEmojisBackground: View {
        private let items: [(String, CGFloat, CGFloat, CGFloat, Double, Double)] = [
            ("Avocado", 0.08, 0.05, 70, -15, 0.0),
            ("Tomato", 0.92, 0.10, 44, 20, 0.3),
            ("Broccoli", 0.30, 0.18, 62, -10, 0.7),
            ("Corn", 0.78, 0.24, 48, 25, 1.0),
            ("Chili Pepper", 0.05, 0.35, 38, -20, 0.5),
            ("Beet", 0.95, 0.40, 56, 15, 1.5),
            ("Garlic", 0.22, 0.48, 72, -25, 0.2),
            ("Banana", 0.70, 0.52, 42, 10, 1.8),
            ("Lemon", 0.10, 0.65, 54, 20, 0.9),
            ("Bread", 0.85, 0.62, 66, -15, 1.2),
            ("Avocado", 0.50, 0.75, 40, 5, 0.4),
            ("Tomato", 0.15, 0.85, 58, -10, 1.6),
            ("Corn", 0.80, 0.82, 46, 15, 0.1),
            ("Garlic", 0.45, 0.12, 68, -20, 1.3),
            ("Broccoli", 0.62, 0.38, 36, 10, 0.6),
            ("Lemon", 0.35, 0.92, 52, -5, 1.9),
        ]

        private static let imageCache: [String: UIImage] = {
            var cache: [String: UIImage] = [:]
            for name in ["Avocado", "Tomato", "Broccoli", "Corn", "Chili Pepper", "Beet", "Garlic", "Banana", "Lemon", "Bread"] {
                if let url = Bundle.main.url(forResource: name, withExtension: "png"),
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    cache[name] = image
                }
            }
            return cache
        }()

        @State private var animate = false
        @State private var visible = false

        var body: some View {
            GeometryReader { proxy in
                if visible {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        let (name, x, y, size, rotation, delay) = item
                        if let uiImage = Self.imageCache[name] {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: size, height: size)
                                .opacity(0.15)
                                .rotationEffect(.degrees(rotation + (animate ? 10 : -10)))
                                .offset(y: animate ? -8 : 8)
                                .position(
                                    x: proxy.size.width * x,
                                    y: proxy.size.height * y
                                )
                                .animation(
                                    .easeInOut(duration: 3)
                                    .repeatForever(autoreverses: true)
                                    .delay(delay),
                                    value: animate
                                )
                        }
                    }
                    .transition(.opacity)
                }
            }
            .onAppear {
                visible = true
                animate = true
            }
            .allowsHitTesting(false)
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
