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
            icon: "refrigerator.fill",
            title: "Your Pantry",
            description: "Add ingredients you have at home. Keep track of everything in your kitchen in one place.",
            color: DS.ColorToken.primary
        ),
        OnboardingPage(
            icon: "exclamationmark.triangle.fill",
            title: "Know When Things Are About to Go Bad",
            description: "Get notified before your ingredients expire so you can use them up in time and reduce waste.",
            color: DS.ColorToken.warning
        ),
        OnboardingPage(
            icon: "wand.and.stars",
            title: "Generate Recipes",
            description: "Turn your leftovers into delicious meals. We'll suggest recipes based on what's already in your pantry.",
            color: DS.ColorToken.accent
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Page content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    pageView(page)
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
            VStack(spacing: DS.Spacing.space3) {
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(DS.Motion.easeOut) {
                            currentPage += 1
                        }
                    } else {
                        session.completeFeatureOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Let's Go")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(size: .lg, fullWidth: true))

                if currentPage < pages.count - 1 {
                    Button {
                        session.completeFeatureOnboarding()
                    } label: {
                        Text("Skip")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryButtonStyle(size: .lg, fullWidth: true))
                }
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.bottom, DS.Spacing.space8)
        }
        .background(DS.ColorToken.bgPrimary)
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: DS.Spacing.space5) {
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.12))
                    .frame(width: 100, height: 100)

                Image(systemName: page.icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(page.color)
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.space5)
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}
