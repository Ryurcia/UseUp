import SwiftUI
import PhosphorSwift

struct CookbookView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @State private var showingSettings = false
    @State private var showAddRecipeOptions = false
    @State private var showPasteURLSheet = false
    @State private var cookbookRecipeData: RecipeImportData? = nil
    @State private var pendingSheetWork: DispatchWorkItem? = nil
    @State private var selectedTab: CookbookTab = .all
    @State private var selectedMealFilter: MealFilter? = nil
    @State private var searchText = ""
    @State private var navigateToRecipe: Recipe?
    @State private var allergenPendingRecipe: Recipe?
    @State private var allergenWarningDetected: [String] = []
    private enum CookbookTab: CaseIterable {
        case all, personal, saved, shared
        var label: String {
            switch self {
            case .all:      return "All"
            case .personal: return "Personal"
            case .saved:    return "Saved"
            case .shared:   return "Shared"
            }
        }
    }

    private enum MealFilter: String, CaseIterable {
        case breakfast, lunch, dinner, snack
        var label: String { rawValue.capitalized }
        var icon: Image {
            switch self {
            case .breakfast: return Ph.sunHorizon.fill
            case .lunch:     return Ph.sun.fill
            case .dinner:    return Ph.moon.fill
            case .snack:     return Ph.coffee.fill
            }
        }
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var baseRecipes: [Recipe] {
        switch selectedTab {
        case .all:      return savedRecipesStore.savedRecipes
        case .personal: return savedRecipesStore.savedRecipes.filter { !$0.isUserShared }
        case .saved:    return savedRecipesStore.savedRecipes.filter { $0.isUserShared }
        case .shared:   return savedRecipesStore.sharedRecipes
        }
    }

    private var filteredRecipes: [Recipe] {
        var recipes = baseRecipes
        if let meal = selectedMealFilter {
            recipes = recipes.filter {
                savedRecipesStore.savedRecipeCategories[$0.id] == meal.rawValue
            }
        }
        let query = searchQuery
        guard !query.isEmpty else { return recipes }
        return recipes.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.summary.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Sourdough.Spacing.screenMargin) {
                Text("Cookbook")
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.title1)
                Spacer()
                Button { showAddRecipeOptions = true } label: {
                    HStack(spacing: Sourdough.Spacing.iconToLabel) {
                        Ph.plus.regular
                            .frame(width: 14, height: 14)
                        Text("Add")
                            .foregroundStyle(Sourdough.Colors.onAction)
                            .sourdoughTextStyle(.caption)
                    }
                    .foregroundStyle(Sourdough.Colors.onAction)
                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                    .frame(height: 36)
                    .background(Sourdough.Colors.action)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button { showingSettings = true } label: {
                    Ph.gear.regular
                        .frame(width: 22, height: 22)
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                }
                .buttonStyle(.plain)
                NotificationBellButton()
                ProfileNavButton()
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.insideChip)

            premiumContent
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $navigateToRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .sheet(item: $allergenPendingRecipe) { recipe in
            AllergenWarningSheet(recipeName: recipe.title) {
                navigateToRecipe = recipe
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
                .preferredColorScheme(session.preferredColorScheme)
        }
        .sheet(isPresented: $showAddRecipeOptions) {
            AddRecipeOptionsSheet(
                onAddManually: {
                    showAddRecipeOptions = false
                    pendingSheetWork?.cancel()
                    let work = DispatchWorkItem { cookbookRecipeData = RecipeImportData() }
                    pendingSheetWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
                },
                onPasteURL: {
                    showAddRecipeOptions = false
                    pendingSheetWork?.cancel()
                    let work = DispatchWorkItem { showPasteURLSheet = true }
                    pendingSheetWork = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
                }
            )
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPasteURLSheet) {
            PasteURLSheet { importData in
                showPasteURLSheet = false
                pendingSheetWork?.cancel()
                let work = DispatchWorkItem { cookbookRecipeData = importData }
                pendingSheetWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
            }
            .presentationDetents([.height(210)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $cookbookRecipeData) { data in
            ShareRecipeSheet(sheetTitle: "Add Recipe", prefill: data, isCookbookRecipe: true)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: Sourdough.Spacing.iconToLabel) {
            ForEach(CookbookTab.allCases, id: \.label) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    Text(tab.label)
                        .foregroundStyle(selectedTab == tab ? Sourdough.Colors.ink : Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(selectedTab == tab ? Sourdough.Colors.card : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))
                        .shadow(color: selectedTab == tab ? .black.opacity(0.08) : .clear, radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Sourdough.Colors.sunken)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous))
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.vertical, Sourdough.Spacing.rowInternals)
    }

    // MARK: - Premium Content

    private var premiumContent: some View {
        VStack(spacing: 0) {
            tabBar

            HStack(spacing: Sourdough.Spacing.insideChip) {
                Ph.magnifyingGlass.regular
                    .frame(width: 18, height: 18)
                    .foregroundStyle(Sourdough.Colors.faintInk)
                TextField("Search recipes", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.body)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Ph.xCircle.fill
                            .frame(width: 18, height: 18)
                            .foregroundStyle(Sourdough.Colors.faintInk)
                    }
                    .buttonStyle(.plain)
                }
                Menu {
                    Button { selectedMealFilter = nil } label: {
                        Label {
                            Text("All")
                        } icon: {
                            if selectedMealFilter == nil {
                                Ph.check.regular.frame(width: 16, height: 16)
                            }
                        }
                    }
                    Divider()
                    ForEach(MealFilter.allCases, id: \.self) { meal in
                        Button { selectedMealFilter = meal } label: {
                            Label {
                                Text(meal.label)
                            } icon: {
                                if selectedMealFilter == meal {
                                    Ph.check.regular.frame(width: 16, height: 16)
                                } else {
                                    meal.icon.frame(width: 16, height: 16)
                                }
                            }
                        }
                    }
                } label: {
                    Ph.fadersHorizontal.regular
                        .frame(width: 16, height: 16)
                        .foregroundStyle(selectedMealFilter != nil ? Sourdough.Ramp.sage500 : Sourdough.Colors.faintInk)
                }
            }
            .onChange(of: selectedTab) { selectedMealFilter = nil }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .frame(height: 48)
            .background(Sourdough.Colors.sunken)
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                    .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.iconToLabel)
            .padding(.bottom, Sourdough.Spacing.rowInternals)

            if savedRecipesStore.savedRecipes.isEmpty && searchQuery.isEmpty {
                Spacer()
                VStack(spacing: Sourdough.Spacing.rowInternals) {
                    Ph.book.regular
                        .frame(width: 48, height: 48)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                    Text("Your cookbook is empty")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.title2)
                    Text("Save recipes from the community to build your collection.")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.subhead)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Sourdough.Spacing.aboveSectionHead)
                Spacer()
            } else {
                recipeList
            }
        }
    }

    // MARK: - Recipe List

    private var emptyStateMessage: String {
        if !searchQuery.isEmpty { return "No results for \"\(searchQuery)\"" }
        switch selectedTab {
        case .all:      return "Your cookbook is empty"
        case .personal: return "No personal recipes yet"
        case .saved:    return "No saved recipes yet"
        case .shared:   return "No shared recipes yet"
        }
    }

    private var emptyStateSubtitle: String {
        if !searchQuery.isEmpty { return "Try a different search term." }
        switch selectedTab {
        case .all:      return "Save recipes from the community to build your collection."
        case .personal: return "Add one with the button above."
        case .saved:    return "Browse the community to find recipes."
        case .shared:   return "Share a recipe with the community."
        }
    }

    private var recipeList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                if filteredRecipes.isEmpty {
                    VStack(spacing: Sourdough.Spacing.rowInternals) {
                        Group {
                            if searchQuery.isEmpty {
                                Ph.book.regular
                            } else {
                                Ph.magnifyingGlass.regular
                            }
                        }
                        .frame(width: 40, height: 40)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                        Text(emptyStateMessage)
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.rowTitle)
                        Text(emptyStateSubtitle)
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.subhead)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Sourdough.Spacing.aboveSectionHead)
                    .padding(.top, Sourdough.Spacing.aboveSectionHead)
                } else {
                    ForEach(filteredRecipes) { recipe in
                        CookbookListRow(
                            recipe: recipe,
                            category: savedRecipesStore.savedRecipeCategories[recipe.id],
                            onTap: { r in
                                allergenWarningDetected = []
                                let detected = detectAllergens(
                                    in: r,
                                    userAllergies: session.currentUserAllergies,
                                    customAllergy: session.currentUserCustomAllergy
                                )
                                if detected.isEmpty {
                                    navigateToRecipe = r
                                } else {
                                    allergenWarningDetected = detected
                                    allergenPendingRecipe = r
                                }
                            },
                            onUnsave: selectedTab == .saved ? {
                                savedRecipesStore.unsaveRecipe(recipe)
                            } : nil
                        )
                        .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    }
                }
            }
            .padding(.bottom, 96)
        }
    }

}

// MARK: - Cookbook List Row

private struct CookbookListRow: View {
    let recipe: Recipe
    let category: String?
    let onTap: (Recipe) -> Void
    var onUnsave: (() -> Void)? = nil

    var metaLine: String {
        var parts: [String] = ["\(recipe.timeMinutes) min"]
        if recipe.dietType != "any" { parts.append(recipe.dietType.capitalized) }
        parts += recipe.dietaryRestrictions.prefix(2)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button { onTap(recipe) } label: {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                // Thumbnail
                Group {
                    if recipe.isAIGenerated && recipe.imageData == nil && recipe.imagePath == nil {
                        ZStack {
                            LinearGradient(
                                colors: [Sourdough.Colors.action, Sourdough.Ramp.sage500],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Ph.forkKnife.regular
                                .frame(width: 20, height: 20)
                                .foregroundStyle(Sourdough.Colors.onAction.opacity(0.85))
                        }
                    } else {
                        CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: true)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.rowTitle)
                        .lineLimit(1)

                    HStack(spacing: Sourdough.Spacing.iconToLabel) {
                        Ph.clock.regular
                            .frame(width: 11, height: 11)
                            .foregroundStyle(Sourdough.Colors.faintInk)
                        Text(metaLine)
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Ph.caretRight.regular
                    .frame(width: 13, height: 13)
                    .foregroundStyle(Sourdough.Colors.faintInk)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.vertical, Sourdough.Spacing.rowInternals)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Sourdough.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
        .contextMenu {
            if let onUnsave {
                Button(role: .destructive) { onUnsave() } label: {
                    Label {
                        Text("Remove from Saved")
                    } icon: {
                        Ph.bookmark.regular.frame(width: 16, height: 16)
                    }
                }
            }
        }
    }
}

// MARK: - Add Recipe Options Sheet

private struct AddRecipeOptionsSheet: View {
    var onAddManually: () -> Void = {}
    var onPasteURL: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            Spacer()

            Button {
                onAddManually()
            } label: {
                HStack(spacing: Sourdough.Spacing.rowInternals) {
                    Ph.pencil.regular
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Manually")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.rowTitle)
                        Text("Fill in title, ingredients and steps")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)
                    }
                    Spacer()
                    Ph.caretRight.regular
                        .frame(width: 13, height: 13)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                }
                .foregroundStyle(Sourdough.Colors.ink)
                .padding(Sourdough.Spacing.screenMargin)
                .frame(maxWidth: .infinity)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                onPasteURL()
            } label: {
                HStack(spacing: Sourdough.Spacing.rowInternals) {
                    Ph.link.regular
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Paste a URL")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.rowTitle)
                        Text("Import from any recipe website")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)
                    }
                    Spacer()
                    Ph.caretRight.regular
                        .frame(width: 13, height: 13)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                }
                .foregroundStyle(Sourdough.Colors.ink)
                .padding(Sourdough.Spacing.screenMargin)
                .frame(maxWidth: .infinity)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)

        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.vertical, Sourdough.Spacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Sourdough.Colors.canvas)
    }
}
