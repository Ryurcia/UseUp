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
}

// MARK: - Main View

struct NotificationListView: View {
    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var session: AppSession
    @StateObject private var recipeCache = SuggestedRecipeCache.shared

    @State private var selectedTab: NotifTab = .all
    @State private var recipeSearchIngredient: Ingredient? = nil
    @State private var allExpiringItems: [Ingredient] = []
    @State private var todayItems: [Ingredient] = []
    @State private var thisWeekItems: [Ingredient] = []

    private let autoHideInterval: TimeInterval = 3 * 24 * 3600

    // MARK: - Data

    private func shouldHide(_ id: String) -> Bool {
        guard let readAt = pantryStore.notifReadTimestamps[id] else { return false }
        return Date().timeIntervalSince(readAt) >= autoHideInterval
    }

    // Cached so the base expiring list is built once (recomputeExpiring), not 3× per render
    // via todayItems/thisWeekItems/unreadCount each re-filtering pantry.
    private func recomputeExpiring() {
        let all = pantryStore.expiringAlertCandidates()
            .filter { !shouldHide("expiring_\($0.id)") }
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
            guard !pantryStore.dismissedIngredientIds.contains(ingredient.id) else { return false }
            guard let days = ingredient.daysUntilExpiration else { return false }
            return days >= 0 && days <= 3
        }
    }

    private var recipeNotifications: [RecipeNotification] {
        guard session.recipeSuggestionsEnabled else { return [] }
        return recipeSuggestionEligibleItems
            .flatMap { ingredient -> [RecipeNotification] in
                recipeCache.suggestions(for: ingredient).prefix(3).map { suggestion in
                    RecipeNotification(
                        id: "\(ingredient.id)-\(suggestion.id)",
                        recipeName: suggestion.title,
                        matchedIngredient: ingredient.name,
                        cuisine: suggestion.cuisineRaw,
                        timeMinutes: suggestion.timeMinutes
                    )
                }
            }
            .filter { !shouldHide("recipe_\($0.id)") }
    }

    private var unreadCount: Int {
        allExpiringItems.filter { pantryStore.notifReadTimestamps["expiring_\($0.id)"] == nil }.count
            + recipeNotifications.filter { pantryStore.notifReadTimestamps["recipe_\($0.id)"] == nil }.count
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

            if isEmpty {
                emptyStateView
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        switch selectedTab {
                        case .all:      allTabContent
                        case .expiring: expiringTabContent
                        case .recipes:  recipesTabContent
                        }
                    }
                    .padding(.bottom, Sourdough.Spacing.betweenBlocks)
                }
            }
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .preference(key: HideTabBarKey.self, value: true)
        .onAppear {
            recomputeExpiring()
            markAllRead()
        }
        .onChange(of: pantryStore.ingredients) { _, _ in recomputeExpiring() }
        .onChange(of: pantryStore.dismissedIngredientIds) { _, _ in recomputeExpiring() }
        .onChange(of: pantryStore.notifReadTimestamps) { _, _ in recomputeExpiring() }
        .onChange(of: savedRecipesStore.communityRecipes) { _, recipes in
            guard session.recipeSuggestionsEnabled, !recipes.isEmpty else { return }
            SuggestedRecipeCache.shared.refresh(expiringIngredients: recipeSuggestionEligibleItems, allRecipes: recipes)
        }
        .sheet(item: $recipeSearchIngredient) { ingredient in
            RecipeSuggestionSheet(ingredient: ingredient)
                .environmentObject(savedRecipesStore)
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
    private var allTabContent: some View {
        if !todayItems.isEmpty {
            sectionHeader("NEEDS ATTENTION", count: todayItems.count)
            ForEach(todayItems) { item in
                expiringCard(item)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, Sourdough.Spacing.rowInternals)
            }
        }

        if !thisWeekItems.isEmpty {
            sectionHeader("THIS WEEK", count: thisWeekItems.count)
            ForEach(thisWeekItems) { item in
                expiringCard(item)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, Sourdough.Spacing.rowInternals)
            }
        }

        if !recipeNotifications.isEmpty {
            sectionHeader("SUGGESTED RECIPES", count: nil)
            ForEach(recipeNotifications) { notif in
                recipeNotificationCard(notif)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, Sourdough.Spacing.rowInternals)
            }
        }
    }

    @ViewBuilder
    private var expiringTabContent: some View {
        if !todayItems.isEmpty {
            sectionHeader("NEEDS ATTENTION", count: todayItems.count)
            ForEach(todayItems) { item in
                expiringCard(item)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, Sourdough.Spacing.rowInternals)
            }
        }

        if !thisWeekItems.isEmpty {
            sectionHeader("THIS WEEK", count: thisWeekItems.count)
            ForEach(thisWeekItems) { item in
                expiringCard(item)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, Sourdough.Spacing.rowInternals)
            }
        }
    }

    @ViewBuilder
    private var recipesTabContent: some View {
        ForEach(recipeNotifications) { notif in
            recipeNotificationCard(notif)
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.bottom, Sourdough.Spacing.rowInternals)
        }
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

    // MARK: - Expiring Card

    private func expiringCard(_ item: Ingredient) -> some View {
        let notifId = "expiring_\(item.id)"
        let isUnread = pantryStore.notifReadTimestamps[notifId] == nil
        let days = item.daysUntilExpiration
        let state: Sourdough.FreshnessState = item.isExpired ? .expired : Sourdough.FreshnessState(daysUntilExpiration: days ?? 0)
        let chipText = item.isExpired ? "Expired" : (days == 0 ? "Today" : days == 1 ? "1 day" : "\(days ?? 0) days")

        return VStack(spacing: 0) {
            HStack(spacing: Sourdough.Spacing.screenMargin) {
                Text(item.category.icon)
                    .font(.system(size: 22))
                    .frame(width: 50, height: 50)
                    .background(Sourdough.Colors.sunken)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name.capitalized)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.rowTitle)
                        .lineLimit(1)

                    (Text(expirationLabel(item))
                        .foregroundStyle(state.style.label)
                    + Text(infoSuffix(item))
                        .foregroundStyle(Sourdough.Colors.faintInk)
                    )
                    .sourdoughTextStyle(.subhead)
                }

                Spacer()

                FreshnessChip(state: state, dayCountText: chipText)

                Button {
                    pantryStore.dismissNotification(for: item.id)
                } label: {
                    Ph.xCircle.fill
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                }
                .buttonStyle(.plain)
                .padding(.leading, Sourdough.Spacing.iconToLabel)
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
    }

    // MARK: - Recipe Notification Card

    private func recipeNotificationCard(_ notif: RecipeNotification) -> some View {
        let notifId = "recipe_\(notif.id)"
        let isUnread = pantryStore.notifReadTimestamps[notifId] == nil

        return VStack(alignment: .leading, spacing: 0) {
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
                Text("🍽️")
                    .font(.system(size: 22))
                    .frame(width: 50, height: 50)
                    .background(Sourdough.Colors.sunken)
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
        let ids = allExpiringItems.map { "expiring_\($0.id)" }
            + recipeNotifications.map { "recipe_\($0.id)" }
        pantryStore.markAllNotificationsRead(ids: ids)
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
                                savedRecipesStore.isSaved(recipe)
                                    ? savedRecipesStore.unsaveRecipe(recipe)
                                    : savedRecipesStore.saveRecipe(recipe)
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

