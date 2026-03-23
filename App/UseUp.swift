import SwiftUI

@main
struct UseUp: App {
    @StateObject private var session = AppSession(authService: SupabaseAuthService())
    @StateObject private var pantryStore = PantryStore()
    @StateObject private var savedRecipesStore = SavedRecipesStore()
    @Environment(\.scenePhase) private var scenePhase
    private let recipeGenerator: RecipeGenerating = MockRecipeGenerator()

    var body: some Scene {
        WindowGroup {
            AppRootView(recipeGenerator: recipeGenerator)
                .environmentObject(session)
                .environmentObject(pantryStore)
                .environmentObject(savedRecipesStore)
                .tint(DS.ColorToken.primary)
                .preferredColorScheme(session.isDarkMode ? .dark : .light)
                .task {
                    await session.restoreSession()
                    pantryStore.userId = session.currentUserId
                    savedRecipesStore.userId = session.currentUserId
                    await savedRecipesStore.fetchRecipes()
                    if session.isAuthenticated {
                        await pantryStore.fetchIngredients()
                        await ExpirationNotificationScheduler.rescheduleAll(for: pantryStore.ingredients)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active, session.isAuthenticated {
                        Task {
                            await pantryStore.fetchIngredients()
                            await ExpirationNotificationScheduler.rescheduleAll(for: pantryStore.ingredients)
                        }
                    }
                }
                .onChange(of: session.currentUserId) { _, newId in
                    pantryStore.userId = newId
                    savedRecipesStore.userId = newId
                    if newId == nil {
                        pantryStore.clearForSignOut()
                        savedRecipesStore.clearForSignOut()
                        ExpirationNotificationScheduler.cancelAll()
                    } else {
                        Task { await savedRecipesStore.fetchRecipes() }
                    }
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        }
    }
}
