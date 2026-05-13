import SwiftUI
import RevenueCatUI

#Preview("App Root – Authenticated") {
    PreviewContainer {
        AppRootView(recipeGenerator: previewRecipeGenerator)
    }
}

#Preview("App Root – Onboarding") {
    PreviewContainer(authenticated: false) {
        AppRootView(recipeGenerator: previewRecipeGenerator)
    }
}

struct AppRootView: View {
    @EnvironmentObject private var session: AppSession
    let recipeGenerator: RecipeGenerating

    var body: some View {
        Group {
            if session.isCheckingSession {
                SplashView()
            } else if !session.hasSeenGetStarted {
                NavigationStack {
                    GetStartedView()
                }
            } else if !session.isAuthenticated {
                NavigationStack {
                    GetStartedView()
                }
            } else if !session.hasCompletedFeatureOnboarding {
                FeatureOnboardingView()
            } else if !session.hasSeenOnboardingPaywall {
                OnboardingPaywallView {
                    session.hasSeenOnboardingPaywall = true
                }
            } else {
                MainTabView(recipeGenerator: recipeGenerator)
            }
        }
        .animation(.easeInOut, value: session.isCheckingSession)
        .animation(.easeInOut, value: session.hasSeenGetStarted)
        .animation(.easeInOut, value: session.isAuthenticated)
        .animation(.easeInOut, value: session.hasCompletedFeatureOnboarding)
        .animation(.easeInOut, value: session.hasSeenOnboardingPaywall)
    }
}

// MARK: - Onboarding Paywall

private struct OnboardingPaywallView: View {
    let onDismiss: () -> Void

    var body: some View {
        PaywallView()
            .onPurchaseCompleted { _ in
                onDismiss()
            }
            .onRestoreCompleted { _ in
                onDismiss()
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.trailing, DS.Spacing.space5)
                .padding(.top, DS.Spacing.space3)
            }
    }
}
