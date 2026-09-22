import SwiftUI
import PhosphorSwift

// MARK: - Supporting Types

private enum NotifTab: String, CaseIterable {
    case all = "All"
    case expiring = "Expiring"
    case recipes = "Recipes"
}

private struct RecipeNotification: Identifiable {
    let id: String
    let recipeName: String
    let matchedIngredient: String
    let cuisine: String
    let timeMinutes: Int
    let recipe: Recipe?
}

// MARK: - Main View

struct NotificationListView: View {
    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var session: AppSession
    @StateObject private var recipeCache = SuggestedRecipeCache.shared

    @State private var selectedTab: NotifTab = .all
    @State private var recipeSearchIngredient: Ingredient? = nil
    @State private var navigateToRecipe: Recipe? = nil
    @State private var allExpiringItems: [Ingredient] = []
    @State private var todayItems: [Ingredient] = []
    @State private var thisWeekItems: [Ingredient] = []
    @State private var showVerificationSheet = false

    private let autoHideInterval: TimeInterval = 3 * 24 * 3600

    // MARK: - Data

    private func shouldHide(_ readAt: Date?) -> Bool {
        guard let readAt else { return false }
        return Date().timeIntervalSince(readAt) >= autoHideInterval
    }

    // Cached so the base expiring list is built once (recomputeExpiring), not 3× per render
    // via todayItems/thisWeekItems/unreadCount each re-filtering pantry.
    private func recomputeExpiring() {
        let all = pantryStore.expiringAlertCandidates()
            .filter { !shouldHide($0.notifReadAt) }
            .sorted { ($0.expirationDate ?? .distantFuture) < ($1.expirationDate ?? .distantFuture) }
        allExpiringItems = all
        todayItems = all.filter { $0.isExpired || ($0.daysUntilExpiration ?? Int.max) == 0 }
        thisWeekItems = all.filter { ingredient in
            guard let daysUntil = ingredient.daysUntilExpiration else { return false }
            return daysUntil >= 1 && daysUntil <= 7
        }
    }

    private var recipeSuggestionEligibleItems: [Ingredient] {
        pantryStore.ingredients.filter { ingredient in
            guard !ingredient.dismissed else { return false }
            guard let days = ingredient.daysUntilExpiration else { return false }
            return days >= 0 && days <= 3
        }
    }

    private var recipeNotifications: [RecipeNotification] {
        guard session.recipeSuggestionsEnabled else { return [] }
        let allRecipes = savedRecipesStore.savedRecipes + savedRecipesStore.communityRecipes
        return recipeSuggestionEligibleItems
            .flatMap { ingredient -> [RecipeNotification] in
                recipeCache.suggestions(for: ingredient).prefix(3).map { suggestion in
                    RecipeNotification(
                        id: "\(ingredient.id)-\(suggestion.id)",
                        recipeName: suggestion.title,
                        matchedIngredient: ingredient.name,
                        cuisine: suggestion.cuisineRaw,
                        timeMinutes: suggestion.timeMinutes,
                        recipe: allRecipes.first { $0.id == suggestion.id }
                    )
                }
            }
            .filter { !shouldHide(pantryStore.recipeNotifReadTimestamps["recipe_\($0.id)"]) }
            .filter { !pantryStore.dismissedRecipeNotifIDs.contains("recipe_\($0.id)") }
    }

    private var unreadCount: Int {
        allExpiringItems.filter { $0.notifReadAt == nil }.count
            + recipeNotifications.filter { pantryStore.recipeNotifReadTimestamps["recipe_\($0.id)"] == nil }.count
    }

    private var needsAttentionCount: Int { todayItems.count }

    private var isEmpty: Bool {
        switch selectedTab {
        case .all:      return allExpiringItems.isEmpty && recipeNotifications.isEmpty
        case .expiring: return allExpiringItems.isEmpty
        case .recipes:  return recipeNotifications.isEmpty
        }
    }


    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerView
            tabPicker

            if !session.isEmailVerified {
                verifyEmailNotificationRow
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.top, Sourdough.Spacing.rowInternals)
            }

            if isEmpty {
                emptyStateView
            } else {
                List {
                    switch selectedTab {
                    case .all:      allTabContent
                    case .expiring: expiringTabContent
                    case .recipes:  recipesTabContent
                    }

                    Color.clear
                        .frame(height: Sourdough.Spacing.betweenBlocks)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .listRowSpacing(Sourdough.Spacing.insideChip)
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .preference(key: HideTabBarKey.self, value: true)
        .background(SwipeBackEnabler())
        .onAppear {
            recomputeExpiring()
            markAllRead()
        }
        .onChange(of: pantryStore.ingredients) { _, _ in recomputeExpiring() }
        .onChange(of: pantryStore.recipeNotifReadTimestamps) { _, _ in recomputeExpiring() }
        .onChange(of: savedRecipesStore.communityRecipes) { _, recipes in
            guard session.recipeSuggestionsEnabled, !recipes.isEmpty else { return }
            SuggestedRecipeCache.shared.refresh(expiringIngredients: recipeSuggestionEligibleItems, allRecipes: recipes)
        }
        .sheet(item: $recipeSearchIngredient) { ingredient in
            RecipeSuggestionSheet(ingredient: ingredient)
                .environmentObject(savedRecipesStore)
        }
        .sheet(isPresented: $showVerificationSheet) {
            OTPVerificationView(email: session.currentUserEmail ?? "")
                .environmentObject(session)
        }
        .navigationDestination(item: $navigateToRecipe) { recipe in
            RecipeDetailView(recipe: recipe)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center) {
                Button {
                    session.showNotifications = false
                } label: {
                    Ph.caretLeft.regular
                        .frame(width: 17, height: 17)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)

                Text("Notifications")
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.title1)
                    .padding(.leading, Sourdough.Spacing.insideChip)

                Spacer()
            }

            if unreadCount > 0 || needsAttentionCount > 0 {
                let unreadPart = unreadCount > 0 ? "\(unreadCount) unread" : nil
                let attentionPart = needsAttentionCount > 0 ? "\(needsAttentionCount) need attention now" : nil
                let subtitle = [unreadPart, attentionPart].compactMap { $0 }.joined(separator: " · ")

                Text(subtitle)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.subhead)
                    .padding(.leading, 30 + Sourdough.Spacing.insideChip + Sourdough.Spacing.insideChip)
            }
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.screenMargin)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            ForEach(NotifTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .foregroundStyle(
                            selectedTab == tab ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk
                        )
                        .sourdoughTextStyle(.caption)
                        .padding(.horizontal, Sourdough.Spacing.screenMargin)
                        .padding(.vertical, Sourdough.Spacing.insideChip)
                        .background(
                            selectedTab == tab
                                ? Sourdough.Ramp.sage500
                                : Sourdough.Colors.sunken
                        )
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func expiringSection(_ title: String, items: [Ingredient]) -> some View {
        sectionHeader(title, count: items.count)
            .notificationRow()
        ForEach(items) { item in
            expiringCard(item)
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .notificationRow()
        }
    }

    @ViewBuilder
    private var recipeSection: some View {
        sectionHeader("SUGGESTED RECIPES", count: nil)
            .notificationRow()
        ForEach(recipeNotifications) { notif in
            recipeNotificationCard(notif)
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .notificationRow()
        }
    }

    @ViewBuilder
    private var allTabContent: some View {
        if !todayItems.isEmpty {
            expiringSection("NEEDS ATTENTION", items: todayItems)
        }
        if !thisWeekItems.isEmpty {
            expiringSection("THIS WEEK", items: thisWeekItems)
        }
        if !recipeNotifications.isEmpty {
            recipeSection
        }
    }

    @ViewBuilder
    private var expiringTabContent: some View {
        if !todayItems.isEmpty {
            expiringSection("NEEDS ATTENTION", items: todayItems)
        }
        if !thisWeekItems.isEmpty {
            expiringSection("THIS WEEK", items: thisWeekItems)
        }
    }

    @ViewBuilder
    private var recipesTabContent: some View {
        recipeSection
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, count: Int?) -> some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            if let count {
                (Text(title + "  ")
                    + Text("\(count)")
                )
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.sectionHead)
            } else {
                Text(title)
                    .foregroundStyle(Sourdough.Colors.faintInk)
                    .sourdoughTextStyle(.sectionHead)
            }
            Spacer()
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.insideChip)
        .padding(.bottom, Sourdough.Spacing.insideChip)
    }

    // MARK: - Pinned Verify-Email Row

    /// Pinned above all three tabs until `session.isEmailVerified` — rendered outside the `List`
    /// entirely (not a row), so it has no `.swipeActions`/mark-as-read behavior and never enters
    /// `unreadCount`/`NotificationBellButton`'s badge math.
    private var verifyEmailNotificationRow: some View {
        Button {
            Task { await session.sendEmailVerificationCode() }
            showVerificationSheet = true
        } label: {
            HStack(spacing: Sourdough.Spacing.screenMargin) {
                Ph.envelope.regular
                    .frame(width: 22, height: 22)
                    .foregroundStyle(Sourdough.Ramp.honey700)
                    .frame(width: 50, height: 50)
                    .background(Sourdough.Ramp.honey100)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Verify your email")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.rowTitle)
                    Text("Finish setting up your account")
                        .foregroundStyle(Sourdough.Ramp.honey700)
                        .sourdoughTextStyle(.subhead)
                }

                Spacer()

                Ph.caretRight.bold
                    .frame(width: 7, height: 12)
                    .foregroundStyle(Sourdough.Ramp.honey500)
            }
            .padding(Sourdough.Spacing.screenMargin)
        }
        .buttonStyle(.plain)
        .background(Sourdough.Ramp.honey50)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(Sourdough.Ramp.honey200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
    }

    // MARK: - Expiring Card

    private func expiringCard(_ item: Ingredient) -> some View {
        let isUnread = item.notifReadAt == nil
        let days = item.daysUntilExpiration
        let state: Sourdough.FreshnessState = item.isExpired ? .expired : Sourdough.FreshnessState(daysUntilExpiration: days ?? 0)
        let chipText = item.isExpired ? "Expired" : (days == 0 ? "Today" : days == 1 ? "1 day" : "\(days ?? 0) days")

        return VStack(spacing: 0) {
            HStack(spacing: Sourdough.Spacing.screenMargin) {
                Text(item.icon ?? item.category.icon)
                    .font(.system(size: 22))
                    .frame(width: 50, height: 50)
                    .background(Sourdough.Colors.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name.capitalized)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.rowTitle)
                        .lineLimit(1)

                    (Text(expirationLabel(item))
                        .foregroundStyle(state.inkSafeLabel)
                    + Text(infoSuffix(item))
                        .foregroundStyle(Sourdough.Colors.faintInk)
                    )
                    .sourdoughTextStyle(.subhead)
                }

                Spacer()

                FreshnessChip(state: state, dayCountText: chipText)
            }
            .padding(.top, Sourdough.Spacing.screenMargin)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.rowInternals)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Sourdough.Ramp.honey500)
                    .frame(width: 8, height: 8)
                    .opacity(isUnread ? 1 : 0)
                    .padding(.top, Sourdough.Spacing.rowInternals)
                    .padding(.trailing, Sourdough.Spacing.rowInternals)
            }

            if !item.isExpired {
                Button {
                    recipeSearchIngredient = item
                } label: {
                    HStack {
                        Text("Suggested Recipes")
                            .foregroundStyle(Sourdough.Colors.actionInk)
                            .sourdoughTextStyle(.caption)
                        Spacer()
                        Ph.caretRight.regular
                            .frame(width: 11, height: 11)
                            .foregroundStyle(Sourdough.Colors.faintInk)
                    }
                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                    .padding(.vertical, Sourdough.Spacing.rowInternals)
                    .background(Sourdough.Colors.sunken)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Sourdough.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { pantryStore.dismissNotification(for: item.id) }
            } label: {
                Label { Text("Delete") } icon: { Image(systemName: "trash") }
            }
            .tint(Sourdough.Colors.destructive)
        }
    }

    // MARK: - Recipe Notification Card

    private func recipeNotificationCard(_ notif: RecipeNotification) -> some View {
        let notifId = "recipe_\(notif.id)"
        let isUnread = pantryStore.recipeNotifReadTimestamps[notifId] == nil

        return Button {
            if let recipe = notif.recipe {
                navigateToRecipe = recipe
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text("Suggested")
                    .foregroundStyle(Sourdough.Ramp.honey600)
                    .sourdoughTextStyle(.sectionHead)
                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                    .padding(.vertical, 4)
                    .background(Sourdough.Ramp.honey100)
                    .clipShape(Capsule())
                    .padding(.top, Sourdough.Spacing.rowInternals)
                    .padding(.leading, Sourdough.Spacing.screenMargin)

                HStack(spacing: Sourdough.Spacing.screenMargin) {
                    Group {
                        if let recipe = notif.recipe, recipe.imagePath != nil || recipe.imageData != nil {
                            CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: true)
                        } else {
                            Text("🍽️")
                                .font(.system(size: 22))
                        }
                    }
                    .frame(width: 50, height: 50)
                    .background(Sourdough.Colors.canvas)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(notif.recipeName)
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.rowTitle)
                            .lineLimit(1)

                        (Text("Uses your \(notif.matchedIngredient.lowercased())")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                        + Text("  ·  \(notif.cuisine) · \(notif.timeMinutes) min")
                            .foregroundStyle(Sourdough.Colors.faintInk)
                        )
                        .sourdoughTextStyle(.subhead)
                    }

                    Spacer()

                    Ph.caretRight.regular
                        .frame(width: 13, height: 13)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                }
                .padding(.top, Sourdough.Spacing.screenMargin)
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.bottom, Sourdough.Spacing.rowInternals)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Sourdough.Ramp.honey500)
                        .frame(width: 8, height: 8)
                        .opacity(isUnread ? 1 : 0)
                        .padding(.top, Sourdough.Spacing.rowInternals)
                        .padding(.trailing, Sourdough.Spacing.rowInternals)
                }
            }
            .background(Sourdough.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                withAnimation { pantryStore.dismissRecipeNotification("recipe_\(notif.id)") }
            } label: {
                Label { Text("Delete") } icon: { Image(systemName: "trash") }
            }
            .tint(Sourdough.Colors.destructive)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            Spacer()
            Ph.bellSlash.regular
                .frame(width: 40, height: 40)
                .foregroundStyle(Sourdough.Colors.faintInk)

            Text("All clear!")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.title2)

            Text("No notifications right now.")
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.subhead)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func expirationLabel(_ item: Ingredient) -> String {
        if item.isExpired { return "Expired" }
        let daysUntil = item.daysUntilExpiration ?? 0
        if daysUntil == 0 { return "Expires today" }
        if daysUntil == 1 { return "Expires tomorrow" }
        return "Expires in \(daysUntil) days"
    }

    private func infoSuffix(_ item: Ingredient) -> String {
        var parts: [String] = []
        if let amount = item.amount, !amount.isEmpty { parts.append(amount) }
        parts.append(item.location.title)
        return " · " + parts.joined(separator: " · ")
    }

    private func markAllRead() {
        pantryStore.markAllExpiringNotificationsRead(ids: allExpiringItems.map(\.id))
        pantryStore.markAllRecipeNotificationsRead(ids: recipeNotifications.map { "recipe_\($0.id)" })
    }
}

// MARK: - List Row Styling

private extension View {
    /// Strips the default `List` row chrome so notification cards sit flush on the canvas,
    /// matching the pantry list rows.
    func notificationRow() -> some View {
        self
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

// MARK: - Recipe Suggestion Sheet

private struct RecipeSuggestionSheet: View {
    let ingredient: Ingredient
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cache = SuggestedRecipeCache.shared
    @State private var selectedRecipe: Recipe? = nil
    @State private var recipePendingSaveFlow: Recipe?
    @State private var recipePendingCollectionPick: Recipe?

    private var suggestions: [SuggestedRecipeCache.Suggestion] {
        cache.suggestions(for: ingredient)
    }

    @ViewBuilder
    private var suggestionsListContent: some View {
        let allRecipes = savedRecipesStore.savedRecipes + savedRecipesStore.communityRecipes
        let resolvedRecipes: [Recipe] = suggestions.compactMap { suggestion in
            allRecipes.first { $0.id == suggestion.id }
        }

        ScrollView(showsIndicators: false) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: Sourdough.Spacing.screenMargin),
                          GridItem(.flexible(), spacing: Sourdough.Spacing.screenMargin)],
                spacing: Sourdough.Spacing.screenMargin
            ) {
                ForEach(resolvedRecipes) { recipe in
                    Button {
                        selectedRecipe = recipe
                    } label: {
                        RecipeCard(
                            recipe: recipe,
                            showBadge: false,
                            isSaved: savedRecipesStore.isSaved(recipe),
                            onSave: {
                                if savedRecipesStore.isSaved(recipe) {
                                    savedRecipesStore.unsaveRecipe(recipe)
                                } else {
                                    recipePendingSaveFlow = recipe
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.betweenBlocks)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if suggestions.isEmpty {
                    VStack(spacing: Sourdough.Spacing.rowInternals) {
                        Spacer()
                        Ph.forkKnife.regular
                            .frame(width: 40, height: 40)
                            .foregroundStyle(Sourdough.Colors.faintInk)

                        Text("No matching recipes found")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.title2)

                        Text("Generate a recipe that uses your \(ingredient.name.lowercased()) before it expires.")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.subhead)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Sourdough.Spacing.betweenBlocks)

                        Button {
                            dismiss()
                            session.requestedIngredientID = ingredient.id
                            session.requestedTab = .generate
                        } label: {
                            Label {
                                Text("Generate a Recipe")
                                    .foregroundStyle(Sourdough.Colors.onAction)
                                    .sourdoughTextStyle(.rowTitle)
                            } icon: {
                                Ph.lightning.fill
                                    .frame(width: 15, height: 15)
                            }
                                .foregroundStyle(Sourdough.Colors.onAction)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Sourdough.Colors.action)
                                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Sourdough.Spacing.screenMargin)
                        .padding(.top, Sourdough.Spacing.insideChip)

                        Spacer()
                    }
                } else {
                    suggestionsListContent
                }
            }
            .navigationDestination(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(item: $recipePendingSaveFlow) { recipe in
                SaveChoiceSheet(
                    onSaveToCollection: {
                        recipePendingSaveFlow = nil
                        recipePendingCollectionPick = recipe
                    },
                    onJustSave: {
                        savedRecipesStore.saveRecipe(recipe)
                        recipePendingSaveFlow = nil
                    }
                )
                .presentationDetents([.height(220)])
            }
            .sheet(item: $recipePendingCollectionPick) { recipe in
                CollectionPickerSheet(recipe: recipe) {
                    recipePendingCollectionPick = nil
                }
                .presentationDetents([.medium, .large])
            }
            .navigationTitle("Recipes using \(ingredient.name.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Sourdough.Colors.actionInk)
                        .sourdoughTextStyle(.rowTitle)
                }
            }
        }
    }
}

