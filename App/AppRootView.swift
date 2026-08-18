import SwiftUI
import LocalAuthentication
import PhosphorSwift

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
            } else if !session.isAuthenticated {
                GetStartedView()
            } else if session.requiresBiometricAuth {
                BiometricSignInView()
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
        .animation(.easeInOut, value: session.isAuthenticated)
        .animation(.easeInOut, value: session.requiresBiometricAuth)
        .animation(.easeInOut, value: session.hasCompletedFeatureOnboarding)
        .animation(.easeInOut, value: session.hasSeenOnboardingPaywall)
    }
}

// MARK: - Biometric Sign-In

private struct BiometricSignInView: View {
    @EnvironmentObject private var session: AppSession
    @State private var authError: String?

    var body: some View {
        VStack(spacing: DS.Spacing.space6) {
            Spacer()

            VStack(spacing: DS.Spacing.space4) {
                Ph.fingerprint.regular
                    .frame(width: 56, height: 56)
                    .foregroundStyle(DS.ColorToken.accent)

                VStack(spacing: DS.Spacing.space2) {
                    Text("Welcome back")
                        .font(.custom("CalSans-Regular", size: 32))
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    Text("Sign in with Face ID to continue")
                        .font(.custom("Satoshi Variable", size: 15))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
            }

            if let error = authError {
                Text(error)
                    .font(.custom("Satoshi Variable", size: 13))
                    .foregroundStyle(DS.ColorToken.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.space5)
            }

            Spacer()

            VStack(spacing: DS.Spacing.space3) {
                Button { authenticate() } label: {
                    Label {
                        Text("Sign in with Face ID")
                    } icon: {
                        Ph.fingerprint.regular
                            .frame(width: 20, height: 20)
                    }
                    .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(DS.ColorToken.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DS.Spacing.space5)

                Button {
                    session.signOut()
                } label: {
                    Text("Use a different account")
                        .font(.custom("Satoshi Variable", size: 14))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, DS.Spacing.space8)
        }
        .background(DS.ColorToken.bgPrimary)
        .task { authenticate() }
    }

    private func authenticate() {
        authError = nil
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            authError = "Face ID is not available on this device."
            return
        }
        Task {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Sign in to UseUp"
                )
                if success { session.completeBiometricAuth() }
            } catch {
                authError = "Authentication failed. Try again."
            }
        }
    }
}

// MARK: - Onboarding Paywall

private struct OnboardingPaywallView: View {
    let onDismiss: () -> Void

    var body: some View {
        UseUpPaywallView(onDismiss: onDismiss)
    }
}
