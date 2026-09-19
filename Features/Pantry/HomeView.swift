import SwiftUI
import UIKit
import PhosphorSwift

struct HomeView: View {
    /// Whether Home is the currently selected tab. `MainTabView` keeps all four screens mounted
    /// (opacity-toggled, not a real `TabView`), so this is how Home learns it's been navigated
    /// away from — used to close the nav search + keyboard.
    var isActiveTab: Bool = true

    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var activityStore: UserActivityStore
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore

    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var searchFocused: Bool
    @State private var ingredientBeingEdited: Ingredient?
    @State private var ingredientBeingUsed: Ingredient?
    @State private var selectedIngredient: Ingredient?
    @State private var showingExpiredItems = false
    @State private var isExpiringListExpanded = false
    @State private var selectedCookTodayRecipe: Recipe?
    @State private var allergenPendingCookTodayRecipe: Recipe?
    @State private var allergenWarningDetected: [String] = []
    @State private var navigateToCookTodayRecipe: Recipe?
    @State private var quickSuggestionIngredients: [Ingredient] = []
    @State private var lockedCookTodayRecipes: [Recipe] = []
    private var greetingName: String {
        if let displayName = session.currentUserDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        return "there"
    }

    private var showSkeleton: Bool {
        pantryStore.isLoading && pantryStore.ingredients.isEmpty
    }

    /// When a priced ingredient's quantity is edited, re-derive its total cost locally from the
    /// stored per-unit cost — no new Gemini call. Returns nil (leaving the stored total untouched)
    /// when there's no stored unit cost, or the new unit can't be converted to the cost unit.
    private func recomputedCost(for ingredient: Ingredient, newAmount: String?, newUnitCount: Int) -> Double? {
        guard let unitCost = ingredient.estimatedUnitCost, let costUnit = ingredient.costUnit else { return nil }
        let (quantity, unit): (Double, String) = {
            if let newAmount, let parsed = QuantityConverter.parse(newAmount), parsed.unit != .unknown, parsed.unit != .piece {
                return (parsed.value, parsed.unit.label)
            }
            return (1, "whole")
        }()
        guard let converted = QuantityConverter.convertQuantity(quantity, from: unit, to: costUnit) else { return nil }
        let total = converted * Double(max(newUnitCount, 1)) * unitCost
        return (total * 100).rounded() / 100
    }

    var body: some View {
        withSheets
            .task {
                await pantryStore.fetchIngredients()
                refreshQuickSuggestionsIfNeeded()
                refreshCookTodayIfNeeded()
            }
            .onChange(of: pantryStore.ingredients) { _, _ in
                refreshQuickSuggestionsIfNeeded()
                refreshCookTodayIfNeeded()
            }
            .onChange(of: savedRecipesStore.communityRecipes) { _, _ in refreshCookTodayIfNeeded() }
            .onChange(of: isActiveTab) { _, active in
                if !active, isSearchActive { dismissSearch() }
            }
            .preference(key: HideTabBarKey.self, value: isSearchActive)
    }

    private var withSheets: some View {
        withOverlays
            .sheet(item: $ingredientBeingEdited) { ingredient in
                EditIngredientSheet(ingredient: ingredient) { name, amount, unitCount, quantityEstimate, quantitySource, category, location, expirationDate, icon in
                    withAnimation {
                        pantryStore.updateIngredient(
                            id: ingredient.id, name: name, amount: amount, unitCount: unitCount,
                            quantityEstimate: quantityEstimate, quantitySource: quantitySource,
                            category: category, location: location, expirationDate: expirationDate, icon: icon,
                            estimatedTotalCost: recomputedCost(for: ingredient, newAmount: amount, newUnitCount: unitCount)
                        )
                    }
                }
            }
            .sheet(item: $ingredientBeingUsed) { ingredient in
                UseIngredientSheet(ingredient: ingredient) { newAmount in
                    withAnimation { pantryStore.useIngredient(id: ingredient.id, newAmount: newAmount) }
                    if newAmount == nil { activityStore.logEvent(type: .itemSaved) }
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $selectedIngredient) { ingredient in
                IngredientDetailSheet(
                    item: ingredient,
                    onUse: {
                        selectedIngredient = nil
                        ingredientBeingUsed = ingredient
                    },
                    onEdit: {
                        selectedIngredient = nil
                        ingredientBeingEdited = ingredient
                    },
                    onQuickGenerate: {
                        selectedIngredient = nil
                        session.requestedQuickGenerateIngredientID = ingredient.id
                        session.requestedTab = .generate
                    }
                )
                .presentationDetents([.height(500)])
                .presentationDragIndicator(.hidden)
            }
            .sheet(item: $selectedCookTodayRecipe) { recipe in
                RecipePreviewSheet(recipe: recipe) {
                    selectedCookTodayRecipe = nil
                    let detected = detectAllergens(
                        in: recipe,
                        userAllergies: session.currentUserAllergies,
                        customAllergy: session.currentUserCustomAllergy
                    )
                    if detected.isEmpty {
                        navigateToCookTodayRecipe = recipe
                    } else {
                        allergenWarningDetected = detected
                        allergenPendingCookTodayRecipe = recipe
                    }
                }
            }
            .sheet(item: $allergenPendingCookTodayRecipe) { recipe in
                AllergenWarningSheet(recipeName: recipe.title) {
                    navigateToCookTodayRecipe = recipe
                }
            }
    }

    private var withOverlays: some View {
        mainContent
            .background(Sourdough.Colors.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $navigateToCookTodayRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .navigationDestination(isPresented: $showingExpiredItems) {
                ExpiredItemsView()
            }
            .onChange(of: session.requestedPantryHomeReset) { _, _ in
                navigateToCookTodayRecipe = nil
                showingExpiredItems = false
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            if isSearchActive {
                searchNavBar
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                headerView
                    .transition(.opacity)
            }

            if isSearchActive {
                searchResultsBody
            } else {
                normalBody
            }
        }
    }

    // MARK: - Quick Generate

    /// The app's single source of truth for "expiring soon" (`PantryStore.expiringAlertCandidates`,
    /// same data the notification bell/list use), minus already-expired items — matching exactly
    /// what `GenerateView`'s existing quick-generate guards already require. Capped at 15 (soonest
    /// first) to respect Generate's own selection limit.
    private var expiringSoonForQuickGenerate: [Ingredient] {
        Array(
            pantryStore.expiringAlertCandidates()
                .filter { !$0.isExpired }
                .sorted { ($0.daysUntilExpiration ?? Int.max) < ($1.daysUntilExpiration ?? Int.max) }
                .prefix(15)
        )
    }

    /// Falls back to up to 5 random pantry ingredients when nothing's expiring soon, so the
    /// button stays usable for any non-empty pantry rather than only ever working on expiring items.
    private var quickGenerateIngredients: [Ingredient] {
        let expiring = expiringSoonForQuickGenerate
        if !expiring.isEmpty { return expiring }
        return Array(pantryStore.ingredients.shuffled().prefix(5))
    }

    /// Stable (not recomputed per-render) random picks for the "Quick Suggestions" / "Cook Today"
    /// fallbacks — refreshed only when their underlying source actually changes, so the displayed
    /// chips/cards don't reshuffle on unrelated re-renders.
    private func refreshQuickSuggestionsIfNeeded() {
        guard expiringSoonForQuickGenerate.isEmpty else { return }
        quickSuggestionIngredients = Array(pantryStore.ingredients.shuffled().prefix(2))
    }

    /// Persisted so "Cook Today" only changes once per calendar day, *unless* the "Use These
    /// Up Soon" set itself meaningfully changes (an ingredient gets used up, edited past the
    /// expiring window, removed, or newly starts expiring) — tracked via `expiringSignature`
    /// below. Unrelated churn (Recipes-tab pagination refreshing `communityRecipes`, a pantry
    /// edit that doesn't touch the expiring set) still can't reshuffle the picks.
    private struct CookTodaySelection: Codable {
        let dateKey: String
        let recipeIDs: [UUID]
        let expiringSignature: [String]
    }
    private let cookTodayDefaultsKey = "cook_today_selection_v1"

    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private var expiringSignature: [String] {
        expiringSoonForQuickGenerate.map { $0.name.lowercased() }.sorted()
    }

    private func refreshCookTodayIfNeeded() {
        let currentSignature = expiringSignature
        if let stored = loadCookTodaySelection(), stored.dateKey == todayKey, stored.expiringSignature == currentSignature {
            let pool = savedRecipesStore.communityRecipes
            lockedCookTodayRecipes = stored.recipeIDs.compactMap { id in pool.first { $0.id == id } }
            return
        }
        let fresh = cookTodayMatchedRecipes.isEmpty
            ? Array(savedRecipesStore.communityRecipes.shuffled().prefix(3))
            : cookTodayMatchedRecipes
        guard !fresh.isEmpty else { return }
        lockedCookTodayRecipes = fresh
        saveCookTodaySelection(CookTodaySelection(dateKey: todayKey, recipeIDs: fresh.map(\.id), expiringSignature: currentSignature))
    }

    private func loadCookTodaySelection() -> CookTodaySelection? {
        guard let data = UserDefaults.standard.data(forKey: cookTodayDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(CookTodaySelection.self, from: data)
    }

    private func saveCookTodaySelection(_ selection: CookTodaySelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        UserDefaults.standard.set(data, forKey: cookTodayDefaultsKey)
    }

    private var quickGenerateButton: some View {
        let isDisabled = pantryStore.ingredients.isEmpty
        return Button {
            session.requestedQuickGenerateIngredientIDs = Set(quickGenerateIngredients.map(\.id))
            session.requestedTab = .generate
        } label: {
            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                Ph.sparkle.fill
                    .frame(width: 16, height: 16)
                Text("Quick Generate")
            }
            .foregroundStyle(Sourdough.Colors.action)
            .sourdoughTextStyle(.rowTitle)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                    .stroke(Sourdough.Colors.action, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    private var expiringSoonPreview: some View {
        let expiring = expiringSoonForQuickGenerate
        let isFallback = expiring.isEmpty
        let items = isFallback ? quickSuggestionIngredients : expiring
        let visible = isFallback ? items : (isExpiringListExpanded ? items : Array(items.prefix(3)))

        return VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            Text(isFallback ? "Quick Suggestions" : "Use These Up Soon")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.sectionHead)

            VStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(visible) { item in
                    IngredientRowContent(item: item)
                        .background(Sourdough.Colors.card)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
                        .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedIngredient = item }
                }
            }

            if !isFallback && items.count > 3 {
                Button {
                    withAnimation(.easeInOut(duration: DS.Motion.normal)) {
                        isExpiringListExpanded.toggle()
                    }
                } label: {
                    Text(isExpiringListExpanded ? "Show less" : "Show \(items.count - 3) more")
                        .foregroundStyle(Sourdough.Colors.actionInk)
                        .sourdoughTextStyle(.subhead)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Cook Today

    private static let cookTodayMinimumCoverage = 0.6

    /// Recipes ranked by how much of "Use These Up Soon" (`expiringSoonForQuickGenerate`)
    /// they cover — almost all of what's expiring, not just an incidental ingredient or
    /// two from the wider pantry. Same bidirectional, case-insensitive substring match
    /// `RecipesView.recomputeUseUpMatches()` uses. Empty when nothing's expiring or no
    /// community recipe clears the coverage bar — `refreshCookTodayIfNeeded` falls back
    /// to a random community pick in either case.
    private var cookTodayMatchedRecipes: [Recipe] {
        let expiring = expiringSoonForQuickGenerate
        guard !expiring.isEmpty else { return [] }
        let expiringNames = expiring.map { $0.name.lowercased() }

        func coverage(_ recipe: Recipe) -> Double {
            let matched = recipe.ingredientsUsed.filter { ingredient in
                let name = ingredient.name.lowercased()
                return expiringNames.contains { name.contains($0) || $0.contains(name) }
            }.count
            return Double(matched) / Double(expiringNames.count)
        }

        return savedRecipesStore.communityRecipes
            .map { ($0, coverage($0)) }
            .filter { $0.1 >= Self.cookTodayMinimumCoverage }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0.0 }
    }

    private var cookTodaySection: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            Text("Cook Today")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.sectionHead)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Sourdough.Spacing.rowInternals) {
                    ForEach(lockedCookTodayRecipes) { recipe in
                        Button {
                            selectedCookTodayRecipe = recipe
                        } label: {
                            RecipeCard(
                                recipe: recipe,
                                showBadge: false,
                                isSaved: savedRecipesStore.isSaved(recipe),
                                onRate: nil,
                                onSave: {
                                    if savedRecipesStore.isSaved(recipe) {
                                        savedRecipesStore.unsaveRecipe(recipe)
                                    } else {
                                        savedRecipesStore.saveRecipe(recipe)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(width: 225)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var normalBody: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Sourdough.Spacing.aboveSectionHead) {
                if !expiringSoonForQuickGenerate.isEmpty || !pantryStore.ingredients.isEmpty {
                    expiringSoonPreview
                }

                quickGenerateButton

                if !lockedCookTodayRecipes.isEmpty {
                    cookTodaySection
                    Divider().foregroundStyle(Sourdough.Colors.hairline)
                }

                dashboardView
                locationCountsRow
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, 120) // clears the floating bottom tab bar — locationCountsRow is the last section
        }
        .animation(.easeInOut(duration: DS.Motion.normal), value: showSkeleton)
    }

    // MARK: - Dashboard

    private var dashboardView: some View {
        PantryDashboard(
            ingredients: pantryStore.ingredients,
            isLoading: showSkeleton,
            isPantryEmpty: pantryStore.ingredients.isEmpty,
            onShowExpired: { showingExpiredItems = true },
            onAddFirstItem: { session.requestedShowAddIngredient = true }
        )
    }

    // MARK: - Location counts row

    private var locationCountsRow: some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            ForEach(Ingredient.StorageLocation.allCases) { location in
                locationCountCard(location)
            }
        }
    }

    private func locationCountCard(_ location: Ingredient.StorageLocation) -> some View {
        Button {
            session.requestedPantryLocation = location
            session.requestedTab = .pantry
        } label: {
            VStack(spacing: Sourdough.Spacing.insideChip) {
                locationIcon(location)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                Text("\(pantryStore.count(in: location))")
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.title2)
                Text(location.title.uppercased())
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.sectionHead)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Sourdough.Spacing.rowInternals)
            .background(Sourdough.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
        }
        .buttonStyle(.plain)
    }

    private func locationIcon(_ location: Ingredient.StorageLocation) -> Image {
        switch location {
        case .pantry:  return Ph.archive.regular
        case .fridge:  return Ph.doorOpen.regular
        case .freezer: return Ph.snowflake.regular
        }
    }

    // MARK: - Nav search

    private var searchResults: [Ingredient] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = query.isEmpty
            ? pantryStore.ingredients
            : pantryStore.ingredients.filter { $0.name.localizedCaseInsensitiveContains(query) }

        return base.sorted { ($0.daysUntilExpiration ?? Int.max) < ($1.daysUntilExpiration ?? Int.max) }
    }

    private var searchableRecipes: [Recipe] {
        var seen = Set<UUID>()
        return (savedRecipesStore.communityRecipes + savedRecipesStore.savedRecipes)
            .filter { seen.insert($0.id).inserted }
    }

    private var recipeSearchResults: [Recipe] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        return searchableRecipes.filter {
            $0.title.lowercased().contains(query) || $0.summary.lowercased().contains(query)
        }
    }

    private var searchNavBar: some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            Ph.magnifyingGlass.regular
                .frame(width: 18, height: 18)
                .foregroundStyle(Sourdough.Colors.faintInk)

            TextField("Search ingredients & recipes", text: $searchText)
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.body)

            Button { dismissSearch() } label: {
                Ph.x.bold
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .frame(width: 24, height: 24)
                    .background(Sourdough.Colors.card)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Sourdough.Spacing.rowInternals)
        .frame(height: 48)
        .background(Sourdough.Colors.sunken)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.iconToLabel)
        .padding(.bottom, Sourdough.Spacing.betweenBlocks)
        .task {
            try? await Task.sleep(for: .milliseconds(50))
            searchFocused = true
        }
    }

    @ViewBuilder
    private var searchResultsBody: some View {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let ingredientResults = searchResults
        let recipeResults = recipeSearchResults

        if !query.isEmpty && ingredientResults.isEmpty && recipeResults.isEmpty {
            VStack(spacing: 0) {
                Spacer()
                Text("No results found")
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.body)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if !ingredientResults.isEmpty {
                    Section {
                        ForEach(ingredientResults) { item in
                            ExpandableIngredientRow(
                                item: item,
                                onSelect: { selectedIngredient = item },
                                onBin: {
                                    if item.isExpired { activityStore.logEvent(type: .itemWasted) }
                                    withAnimation { pantryStore.deleteIngredient(id: item.id) }
                                },
                                onUse: {
                                    withAnimation { pantryStore.useIngredient(id: item.id, newAmount: nil) }
                                    activityStore.logEvent(type: .itemSaved)
                                }
                            )
                            .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text("INGREDIENTS")
                            .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)
                            .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            .listRowInsets(EdgeInsets())
                    }
                }

                if !recipeResults.isEmpty {
                    Section {
                        ForEach(recipeResults) { recipe in
                            recipeSearchRow(recipe)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text("RECIPES")
                            .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)
                            .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            .listRowInsets(EdgeInsets())
                    }
                }

                Color.clear
                    .frame(height: Sourdough.Spacing.underTitle * 2)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .listRowSpacing(Sourdough.Spacing.insideChip)
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func recipeSearchRow(_ recipe: Recipe) -> some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            Ph.forkKnife.regular
                .frame(width: 14, height: 14)
                .foregroundStyle(Sourdough.Ramp.sage600)
                .frame(width: 32, height: 32)
                .background(Sourdough.Ramp.sage100)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.title)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.rowTitle)
                    .lineLimit(1)
                if !recipe.summary.isEmpty {
                    Text(recipe.summary)
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.subhead)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Ph.caretRight.regular
                .frame(width: 9, height: 12)
                .foregroundStyle(Sourdough.Colors.faintInk)
        }
        .padding(Sourdough.Spacing.rowInternals)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .contentShape(Rectangle())
        .onTapGesture { selectedCookTodayRecipe = recipe }
    }

    private func activateSearch() {
        withAnimation(.easeInOut(duration: DS.Motion.normal)) { isSearchActive = true }
    }

    private func dismissSearch() {
        searchFocused = false
        withAnimation(.easeInOut(duration: DS.Motion.normal)) { isSearchActive = false }
        searchText = ""
    }

    private var headerView: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            HStack(spacing: Sourdough.Spacing.screenMargin) {
                Text("Today is \(Date.now, format: .dateTime.month(.wide).day())")
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.subhead)

                Spacer()

                NavChipButton(icon: Ph.magnifyingGlass.regular) { activateSearch() }
                NotificationBellButton()
                ProfileNavButton()
            }

            Text("Hey \(greetingName)! 👋")
                .sourdoughTextStyle(.display)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.iconToLabel)
        .padding(.bottom, Sourdough.Spacing.betweenBlocks)
    }

}

// MARK: - Extracted Equatable Ingredient Row

struct IngredientRowContent: View, Equatable {
    let item: Ingredient

    static func == (lhs: IngredientRowContent, rhs: IngredientRowContent) -> Bool {
        lhs.item == rhs.item
    }

    var body: some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            Text(item.icon ?? item.category.icon)
                .font(.system(size: 22))
                .frame(width: 44, height: 44)
                .background(item.freshnessState.style.tint)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.capitalized)
                    .sourdoughTextStyle(.rowTitle)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let amount = item.displayAmount, !amount.isEmpty {
                        Text(amount)
                        Text("·")
                    }
                    Text(item.location.title)
                    if let cost = item.estimatedTotalCost {
                        Text("·")
                        Text(String(format: "$%.2f", cost))
                            .foregroundStyle(item.costSource == "openfoodfacts" ? Sourdough.Ramp.honey700 : Sourdough.Ramp.sage600)
                    }
                }
                .sourdoughTextStyle(.subhead)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                freshnessChip(item: item)
                if let date = item.expirationDate {
                    Text("Exp \(Self.formatExpiration(date))")
                        .foregroundStyle(Sourdough.Colors.faintInk)
                        .sourdoughTextStyle(.caption)
                }
            }
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .frame(height: 72)
    }

    @ViewBuilder
    private func freshnessChip(item: Ingredient) -> some View {
        let state = item.freshnessState
        FreshnessChip(state: state, dayCountText: Self.chipText(state: state, days: item.daysUntilExpiration))
    }

    /// Mockup-matching chip copy: "Use today" at day 0, bare day count while soon, "Fresh" (with an
    /// approximate week count only inside a useful ~2-month window) once comfortably out, "Expired" past.
    static func chipText(state: Sourdough.FreshnessState, days: Int?) -> String {
        switch state {
        case .expired:
            return "Expired"
        case .urgent:
            return "Use today"
        case .soon:
            let n = days ?? 0
            return "\(n) day\(n == 1 ? "" : "s")"
        case .fresh:
            guard let days, days > 0 else { return "Fresh" }
            let weeks = Int((Double(days) / 7.0).rounded())
            guard weeks >= 1 && weeks <= 8 else { return "Fresh" }
            return "Fresh · \(weeks) wk\(weeks == 1 ? "" : "s")"
        }
    }

    private static let expirationFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    static func formatExpiration(_ date: Date) -> String {
        let year = Calendar.current.component(.year, from: date)
        let currentYear = Calendar.current.component(.year, from: Date())
        if year != currentYear {
            let f = DateFormatter()
            f.dateFormat = "MMM d, yyyy"
            return f.string(from: date)
        }
        return expirationFormatter.string(from: date)
    }
}

extension Ingredient {
    var freshnessState: Sourdough.FreshnessState {
        if isExpired { return .expired }
        guard let days = daysUntilExpiration else { return .fresh }
        return Sourdough.FreshnessState(daysUntilExpiration: days)
    }
}

/// A single pantry ingredient card. Tapping presents `IngredientDetailSheet`; swiping from the
/// trailing edge deletes it (full swipe deletes instantly). Native `.swipeActions` is used
/// deliberately — a hand-rolled `DragGesture` on a row inside a `List` strands the scroll view's
/// pan recognizer after each touch, freezing scrolling until the next gesture.
struct ExpandableIngredientRow: View {
    let item: Ingredient
    let onSelect: () -> Void
    let onBin: () -> Void
    let onUse: () -> Void

    var body: some View {
        IngredientRowContent(item: item)
            .background(Sourdough.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onBin) {
                    Label("Bin", systemImage: "trash")
                }
                .tint(Sourdough.Colors.destructive)

                Button(action: onUse) {
                    Label("Use", systemImage: "checkmark")
                }
                .tint(Sourdough.Ramp.sage500)
            }
    }
}

// MARK: - Ingredient Detail Sheet

struct IngredientDetailSheet: View {
    let item: Ingredient
    let onUse: () -> Void
    let onEdit: () -> Void
    let onQuickGenerate: () -> Void

    private var state: Sourdough.FreshnessState { item.freshnessState }

    private var statusLabel: String {
        switch state {
        case .expired: return "Expired"
        case .urgent:  return "Use today"
        case .soon:    return "Expiring soon"
        case .fresh:   return "Fresh"
        }
    }

    private var statusColor: Color { state.inkSafeLabel }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.betweenBlocks)

            HStack(spacing: Sourdough.Spacing.rowInternals) {
                Text(item.icon ?? item.category.icon)
                    .font(.system(size: 30))
                    .frame(width: 64, height: 64)
                    .background(Sourdough.Colors.sunken)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name.capitalized)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.title2)
                        .lineLimit(1)

                    if let date = item.expirationDate {
                        Text("\(statusLabel) · \(IngredientRowContent.formatExpiration(date))")
                            .foregroundStyle(statusColor)
                            .sourdoughTextStyle(.subhead)
                    } else {
                        Text(statusLabel)
                            .foregroundStyle(statusColor)
                            .sourdoughTextStyle(.subhead)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)

            VStack(spacing: 0) {
                detailRow(label: "Quantity", value: (item.amount?.isEmpty == false ? item.amount : nil) ?? "—")
                if let cost = item.estimatedTotalCost {
                    detailRow(
                        label: item.costSource == "personal" ? "Your price" : "Est. cost",
                        value: String(format: "$%.2f", cost),
                        valueColor: item.costSource == "openfoodfacts" ? Sourdough.Ramp.honey700 : Sourdough.Ramp.sage600
                    )
                }
                detailRow(label: "Location", value: item.location.title)
                detailRow(label: "Category", value: item.category.title)
                detailRow(
                    label: "Expires",
                    value: item.expirationDate.map(IngredientRowContent.formatExpiration) ?? "—",
                    valueColor: item.expirationDate != nil ? statusColor : nil
                )
            }
            .padding(.top, Sourdough.Spacing.betweenBlocks)

            if !item.isExpired {
                Button(action: onQuickGenerate) {
                    HStack(spacing: Sourdough.Spacing.insideChip) {
                        Ph.lightning.fill
                            .frame(width: 14, height: 14)
                        Text("Quick Generation")
                            .sourdoughTextStyle(.rowTitle)
                        Spacer()
                        Ph.caretRight.regular
                            .frame(width: 11, height: 11)
                            .foregroundStyle(Sourdough.Colors.faintInk)
                    }
                    .foregroundStyle(Sourdough.Colors.actionInk)
                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                    .padding(.vertical, Sourdough.Spacing.rowInternals)
                    .background(Sourdough.Colors.sunken)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.betweenBlocks)
            }

            GeometryReader { proxy in
                HStack(spacing: Sourdough.Spacing.insideChip) {
                    Button(action: onUse) {
                        Text("Use Up")
                            .foregroundStyle(Sourdough.Colors.onAction)
                            .sourdoughTextStyle(.rowTitle)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Sourdough.Ramp.sage500)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .frame(width: proxy.size.width * 0.62)

                    Button(action: onEdit) {
                        Text("Edit")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.rowTitle)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Sourdough.Colors.sunken)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 52)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.betweenBlocks)
            .padding(.bottom, Sourdough.Spacing.screenMargin)

            Spacer(minLength: 0)
        }
        .background(Sourdough.Colors.canvas)
    }

    private func detailRow(label: String, value: String, valueColor: Color? = nil) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.body)
                Spacer()
                Text(value)
                    .foregroundStyle(valueColor ?? Sourdough.Colors.ink)
                    .sourdoughTextStyle(.rowTitle)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.vertical, Sourdough.Spacing.rowInternals)

            Divider().foregroundStyle(Sourdough.Colors.hairline)
                .padding(.leading, Sourdough.Spacing.screenMargin)
        }
    }
}

#Preview("Home") {
    PreviewContainer {
        NavigationStack {
            HomeView()
        }
    }
}

// MARK: - Use Ingredient Sheet

struct UseIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss

    let ingredient: Ingredient
    let onUse: (String?) -> Void

    @State private var usageText = ""
    @State private var usageUnit: QuantityConverter.Unit
    @State private var useAll = false

    private let pantryParsed: QuantityConverter.Parsed?

    init(ingredient: Ingredient, onUse: @escaping (String?) -> Void) {
        self.ingredient = ingredient
        self.onUse = onUse
        let p = QuantityConverter.parse(ingredient.totalAmount ?? "")
        self.pantryParsed = p
        _usageUnit = State(initialValue: p?.unit ?? .gram)
    }

    // Units the user can choose from — same category as what's stored
    private var compatibleUnits: [QuantityConverter.Unit] {
        switch pantryParsed?.unit.category {
        case .weight:  return [.gram, .kilogram, .ounce, .pound]
        case .volume:  return [.milliliter, .liter, .cup, .tablespoon, .teaspoon]
        case .count:   return [.piece]
        default:       return []
        }
    }

    private var isParseable: Bool { pantryParsed != nil }

    private var overflowError: String? {
        guard !useAll,
              let usageVal = Double(usageText.trimmingCharacters(in: .whitespaces)),
              usageVal > 0,
              let pantry = pantryParsed else { return nil }
        let usageBase = usageUnit.toBase(usageVal)
        guard usageBase > pantry.toBase() else { return nil }
        let availInUsageUnit = QuantityConverter.formatQuantity(usageUnit.fromBase(pantry.toBase()))
        return "Not enough — only \(ingredient.totalAmount ?? "") / \(availInUsageUnit) \(usageUnit.label) available"
    }

    private var canConfirm: Bool {
        if useAll { return true }
        let trimmed = usageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let val = Double(trimmed), val > 0 else { return false }
        return overflowError == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.betweenBlocks)

            VStack(spacing: Sourdough.Spacing.betweenBlocks) {
                HStack {
                    Text("Use Ingredient")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.title1)
                    Spacer()
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.caption)
                        .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(ingredient.name.capitalized)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.title2)

                    if let amount = ingredient.totalAmount, !amount.isEmpty {
                        Text("Available: \(amount)")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.subhead)
                    } else {
                        Text("No amount set")
                            .foregroundStyle(Sourdough.Colors.faintInk)
                            .sourdoughTextStyle(.subhead)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isParseable {
                    parseableModeContent
                } else {
                    unparseableModeContent
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)

            Spacer()

            Button(action: confirm) {
                Text("Confirm")
                    .foregroundStyle(Sourdough.Colors.onAction)
                    .sourdoughTextStyle(.rowTitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canConfirm ? Sourdough.Ramp.sage500 : Sourdough.Ramp.sage500.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canConfirm)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.rowInternals)
        }
        .background(Sourdough.Colors.canvas)
    }

    // MARK: - Mode A: Parseable amount

    private var parseableModeContent: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                Text("How much are you using?")
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.caption)

                HStack(spacing: Sourdough.Spacing.insideChip) {
                    TextField("0", text: $usageText)
                        .keyboardType(.decimalPad)
                        .onChange(of: usageText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber || $0 == "." }
                            if filtered != newValue { usageText = filtered }
                        }
                        .disabled(useAll)
                        .foregroundStyle(useAll ? Sourdough.Colors.faintInk : Sourdough.Colors.ink)
                        .sourdoughTextStyle(.body)
                        .padding(.horizontal, Sourdough.Spacing.rowInternals)
                        .frame(height: 48)
                        .background(Sourdough.Colors.sunken)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                    if !compatibleUnits.isEmpty {
                        Menu {
                            ForEach(compatibleUnits, id: \.label) { unit in
                                Button {
                                    usageUnit = unit
                                } label: {
                                    HStack {
                                        Text(unit.label)
                                        if usageUnit.label == unit.label {
                                            Ph.check.regular.frame(width: 16, height: 16)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                                Text(usageUnit.label)
                                    .foregroundStyle(Sourdough.Colors.ink)
                                    .sourdoughTextStyle(.caption)
                                Ph.caretDown.regular
                                    .frame(width: 11, height: 11)
                                    .foregroundStyle(Sourdough.Colors.faintInk)
                            }
                            .padding(.horizontal, Sourdough.Spacing.rowInternals)
                            .frame(height: 48)
                            .background(Sourdough.Colors.sunken)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                        }
                        .disabled(useAll)
                    }
                }

                if let error = overflowError {
                    Label {
                        Text(error)
                            .foregroundStyle(Sourdough.Colors.destructive)
                            .sourdoughTextStyle(.subhead)
                    } icon: {
                        Ph.warningCircle.fill.frame(width: 16, height: 16)
                            .foregroundStyle(Sourdough.Colors.destructive)
                    }
                        .padding(.horizontal, Sourdough.Spacing.iconToLabel)
                }
            }

            HStack {
                Text("Use All")
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.body)
                Spacer()
                Toggle("", isOn: $useAll)
                    .labelsHidden()
                    .tint(Sourdough.Ramp.sage500)
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .frame(height: 48)
            .background(Sourdough.Colors.sunken)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
        }
    }

    // MARK: - Mode B: Unparseable / nil amount

    private var unparseableModeContent: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            HStack {
                Text("Use All")
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.body)
                Spacer()
                Toggle("", isOn: $useAll)
                    .labelsHidden()
                    .tint(Sourdough.Ramp.sage500)
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .frame(height: 48)
            .background(Sourdough.Colors.sunken)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

            if !useAll {
                VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                    Text("How much are you using?")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.caption)

                    TextField("e.g. 2 cups", text: $usageText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.body)
                        .padding(.horizontal, Sourdough.Spacing.rowInternals)
                        .frame(height: 48)
                        .background(Sourdough.Colors.sunken)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                }
            }
        }
    }

    // MARK: - Confirm

    private func confirm() {
        if useAll {
            onUse(nil)
            dismiss()
            return
        }

        guard let pantry = pantryParsed,
              let usageVal = Double(usageText.trimmingCharacters(in: .whitespaces)) else {
            onUse(nil)
            dismiss()
            return
        }

        let usageBase = usageUnit.toBase(usageVal)
        let remainingBase = pantry.toBase() - usageBase

        if remainingBase <= 0 {
            onUse(nil)
        } else {
            let remainingInStoredUnit = pantry.unit.fromBase(remainingBase)
            let formatted = QuantityConverter.formatQuantity(remainingInStoredUnit)
            onUse("\(formatted) \(pantry.unit.label)")
        }
        dismiss()
    }
}
