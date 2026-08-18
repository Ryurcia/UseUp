import SwiftUI

@main
struct UseUp: App {
    @StateObject private var session = AppSession(authService: SupabaseAuthService())
    @StateObject private var pantryStore = PantryStore()
    @StateObject private var savedRecipesStore = SavedRecipesStore()
    @StateObject private var activityStore = UserActivityStore()
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    @Environment(\.scenePhase) private var scenePhase
    private let recipeGenerator: RecipeGenerating = GeminiRecipeGenerator()

    init() {
        RevenueCatManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(recipeGenerator: recipeGenerator)
                .environmentObject(session)
                .environmentObject(pantryStore)
                .environmentObject(savedRecipesStore)
                .environmentObject(activityStore)
                .environmentObject(revenueCatManager)
                .tint(DS.ColorToken.primary)
                .preferredColorScheme(session.preferredColorScheme)
                .task {
                    await session.restoreSession()
                    pantryStore.userId = session.currentUserId
                    savedRecipesStore.userId = session.currentUserId
                    savedRecipesStore.currentUserNickname = session.currentUserNickname
                    activityStore.userId = session.currentUserId

                    if session.isAuthenticated, let userId = session.currentUserId {
                        await revenueCatManager.logIn(userId: userId.uuidString)
                    }

                    session.isCheckingSession = false

                    if session.isAuthenticated {
                        async let recipes: Void = savedRecipesStore.fetchRecipes()
                        async let ingredients: Void = pantryStore.fetchIngredients()
                        _ = await (recipes, ingredients)
                        await ExpirationNotificationScheduler.rescheduleAll(for: pantryStore.ingredients)
                    } else {
                        await savedRecipesStore.fetchRecipes()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active, session.isAuthenticated {
                        Task {
                            await revenueCatManager.checkEntitlements()
                            await session.refreshPremiumStatus()
                            await pantryStore.fetchIngredients()
                            await ExpirationNotificationScheduler.rescheduleAll(for: pantryStore.ingredients)
                        }
                    }
                }
                .onChange(of: session.currentUserId) { _, newId in
                    pantryStore.userId = newId
                    savedRecipesStore.userId = newId
                    savedRecipesStore.currentUserNickname = session.currentUserNickname
                    activityStore.userId = newId
                    if let newId {
                        Task {
                            await revenueCatManager.logIn(userId: newId.uuidString)
                            await savedRecipesStore.fetchRecipes()
                        }
                    } else {
                        pantryStore.clearForSignOut()
                        savedRecipesStore.clearForSignOut()
                        activityStore.clearForSignOut()
                        ExpirationNotificationScheduler.cancelAll()
                        Task { await revenueCatManager.logOut() }
                    }
                }
                .onChange(of: revenueCatManager.isPremium) { _, isPremium in
                    if isPremium {
                        session.isPremium = true
                        session.hasSeenOnboardingPaywall = true
                    } else {
                        session.isPremium = false
                        Task { await session.refreshPremiumStatus() }
                    }
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        }
    }
}
