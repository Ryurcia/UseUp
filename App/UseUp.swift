import SwiftUI

@main
struct UseUp: App {
    @StateObject private var session = AppSession(authService: SupabaseAuthService())
    @StateObject private var pantryStore = PantryStore()
    @StateObject private var savedRecipesStore = SavedRecipesStore()
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
                }
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        }
    }
}
