import SwiftUI

/// Wraps any view with the environment objects needed for Xcode canvas previews.
struct PreviewContainer<Content: View>: View {
    @StateObject private var session: AppSession
    @StateObject private var pantryStore: PantryStore
    @StateObject private var savedRecipesStore: SavedRecipesStore
    let content: () -> Content

    init(
        authenticated: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        let session = AppSession(authService: MockAuthService(), profileService: MockProfileService())
        session.isCheckingSession = false
        session.hasSeenGetStarted = authenticated
        session.isAuthenticated = authenticated
        if authenticated {
            session.currentUserPhone = "+15550001234"
            session.currentUserNickname = "Chef"
            session.currentUserDisplayName = "Chef"
        }

        _session = StateObject(wrappedValue: session)
        _pantryStore = StateObject(wrappedValue: PantryStore())
        _savedRecipesStore = StateObject(wrappedValue: SavedRecipesStore())
        self.content = content
    }

    var body: some View {
        content()
            .environmentObject(session)
            .environmentObject(pantryStore)
            .environmentObject(savedRecipesStore)
    }
}

/// A mock recipe generator available in previews.
let previewRecipeGenerator: RecipeGenerating = MockRecipeGenerator()
