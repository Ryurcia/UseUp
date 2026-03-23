import SwiftUI
import UserNotifications

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
            icon: "refrigerator.fill",
            imageName: "STOCK",
            title: "Your Pantry",
            description: "Track everything in your kitchen in one place.",
            color: DS.ColorToken.primary
        ),
        OnboardingPage(
            icon: "wand.and.stars",
            imageName: "PLATES",
            title: "Generate Recipes",
            description: "Turn leftovers into delicious meals with AI.",
            color: DS.ColorToken.accent
        ),
        OnboardingPage(
            icon: "exclamationmark.triangle.fill",
            imageName: "EXPIRE",
            title: "Know Before It Expires",
            description: "Get notified before ingredients go bad.",
            color: DS.ColorToken.warning
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 340)

            // Page indicators
            HStack(spacing: DS.Spacing.space2) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? DS.ColorToken.primary : DS.ColorToken.textTertiary)
                        .frame(width: index == currentPage ? 24 : 8, height: 8)
                        .animation(DS.Motion.easeOut, value: currentPage)
                }
            }
            .padding(.top, DS.Spacing.space6)

            Spacer()

            // Footer
            Group {
                if currentPage < pages.count - 1 {
                    HStack {
                        Button {
                            session.completeFeatureOnboarding()
                        } label: {
                            Text("Skip")
                        }
                        .buttonStyle(SecondaryButtonStyle(size: .lg))

                        Spacer()

                        Button {
                            withAnimation(DS.Motion.easeOut) {
                                currentPage += 1
                            }
                        } label: {
                            Image(systemName: "arrow.right")
                        }
                        .buttonStyle(PrimaryButtonStyle(size: .lg))
                    }
                } else {
                    VStack(spacing: DS.Spacing.space3) {
                        Button {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                                DispatchQueue.main.async {
                                    session.completeFeatureOnboarding()
                                }
                            }
                        } label: {
                            Text("Enable Notifications")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle(size: .lg, fullWidth: true))

                        Button {
                            session.completeFeatureOnboarding()
                        } label: {
                            Text("Maybe Later")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryButtonStyle(size: .lg))
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.bottom, DS.Spacing.space8)
        }
        .background(DS.ColorToken.bgPrimary)
    }

    private func pageView(_ page: OnboardingPage, index: Int) -> some View {
        VStack(spacing: DS.Spacing.space5) {
            if let imageName = page.imageName,
               let uiImage = UIImage(named: imageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            } else {
                ZStack {
                    Circle()
                        .fill(page.color.opacity(0.12))
                        .frame(width: 100, height: 100)

                    Image(systemName: page.icon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(page.color)
                }
            }

            VStack(spacing: DS.Spacing.space3) {
                Text(page.title)
                    .font(.custom("CalSans-Regular", size: 28))
                    .kerning(0)
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .appTextStyle(.body)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .opacity(currentPage == index ? 1 : 0)
        .offset(y: currentPage == index ? 0 : 12)
        .animation(.easeOut(duration: 0.4), value: currentPage)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.space5)
    }
}

private struct OnboardingPage {
    let icon: String
    var imageName: String? = nil
    let title: String
    let description: String
    let color: Color
}
