import SwiftUI

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
            } else if !session.hasCompletedFeatureOnboarding {
                FeatureOnboardingView()
            } else {
                MainTabView(recipeGenerator: recipeGenerator)
            }
        }
        .animation(.easeInOut, value: session.isCheckingSession)
        .animation(.easeInOut, value: session.isAuthenticated)
        .animation(.easeInOut, value: session.hasCompletedFeatureOnboarding)
    }
}
