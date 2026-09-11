import SwiftUI
import UIKit
import PhosphorSwift

struct PantryView: View {
    /// Whether Pantry is the currently selected tab. `MainTabView` keeps all four screens mounted
    /// (opacity-toggled, not a real `TabView`), so this is how Pantry learns it's been navigated
    /// away from — used to close the nav search + keyboard.
    var isActiveTab: Bool = true

    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var activityStore: UserActivityStore

    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var searchFocused: Bool
    @State private var selectedCategories: Set<PantryCategory> = []
    @State private var selectedStorageFilters: Set<IngredientStorageFilter> = []
    @State private var sortOption: SortOption = .expiration
    @State private var showingFilterSheet = false
    @State private var ingredientBeingEdited: Ingredient?
    @State private var ingredientBeingUsed: Ingredient?
    @State private var selectedIngredient: Ingredient?
    @State private var cachedFilteredIngredients: [Ingredient] = []
    @State private var cachedDashboardBaseIngredients: [Ingredient] = []
    @State private var visibleCount = PantryView.pageSize
    private var hasActiveFilters: Bool {
        !selectedStorageFilters.isEmpty || !selectedCategories.isEmpty
    }
    private var greetingName: String {
        if let displayName = session.currentUserDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }
        return "there"
    }

    static let pageSize = 15

    private var showSkeleton: Bool {
        pantryStore.isLoading && pantryStore.ingredients.isEmpty
    }

    private var visibleIngredients: [Ingredient] {
        Array(cachedFilteredIngredients.prefix(visibleCount))
    }

    private var hasMoreToShow: Bool {
        cachedFilteredIngredients.count > visibleCount
    }

    private func loadMore() {
        visibleCount += Self.pageSize
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

    private func recomputeFilteredIngredients() {
        // Category + storage applied, but *not* the freshness-tier filter — this is the base set
        // the dashboard computes its counts from, so selecting a tier never changes the counts
        // shown for the other tiers. Text search is not part of this list — it lives in the
        // expanding nav search (`searchResultsBody`), which renders its own results. Cached (like
        // cachedFilteredIngredients below) so it's computed once per relevant change rather than
        // on every body evaluation.
        let dashboardBase = pantryStore.ingredients.filter { ingredient in
            let matchesCategory = selectedCategories.isEmpty || selectedCategories.contains { $0.matches(ingredient: ingredient) }
            let matchesStorage = selectedStorageFilters.isEmpty || selectedStorageFilters.contains { $0.matches(ingredient: ingredient) }
            return matchesCategory && matchesStorage
        }
        cachedDashboardBaseIngredients = dashboardBase

        switch sortOption {
        case .expiration:
            cachedFilteredIngredients = dashboardBase.sorted {
                ($0.daysUntilExpiration ?? Int.max) < ($1.daysUntilExpiration ?? Int.max)
            }
        case .alphabetical:
            cachedFilteredIngredients = dashboardBase.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
        visibleCount = Self.pageSize
    }

    var body: some View {
        withSheets
            .task {
                await pantryStore.fetchIngredients()
                recomputeFilteredIngredients()
            }
            .onChange(of: selectedCategories) { _, _ in recomputeFilteredIngredients() }
            .onChange(of: selectedStorageFilters) { _, _ in recomputeFilteredIngredients() }
            .onChange(of: sortOption) { _, _ in recomputeFilteredIngredients() }
            .onChange(of: pantryStore.ingredients) { _, _ in recomputeFilteredIngredients() }
            .onChange(of: isActiveTab) { _, active in
                if !active, isSearchActive { dismissSearch() }
            }
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
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    selectedStorageFilters: $selectedStorageFilters,
                    selectedCategories: $selectedCategories
                )
                .presentationDetents([.large])
            }
    }

    private var withOverlays: some View {
        mainContent
            .background(Sourdough.Colors.canvas)
            .toolbar(.hidden, for: .navigationBar)
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

    @ViewBuilder
    private var normalBody: some View {
        dashboardView
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.betweenBlocks)

        List {
            Section {
                if showSkeleton {
                    pantrySkeletonContent
                        .transition(.opacity)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else if cachedFilteredIngredients.isEmpty {
                    Text("No items")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.body)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, Sourdough.Spacing.aboveSectionHead)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(visibleIngredients) { item in
                        ingredientRow(item)
                    }

                    if hasMoreToShow {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, Sourdough.Spacing.screenMargin)
                            Spacer()
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .onAppear { loadMore() }
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                    pantryListHeader
                    itemCountRow
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.vertical, Sourdough.Spacing.rowInternals)
                .background(Sourdough.Colors.canvas)
                .listRowInsets(EdgeInsets())
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
        .animation(.easeInOut(duration: DS.Motion.normal), value: showSkeleton)
    }

    // MARK: - Dashboard

    private var dashboardView: some View {
        PantryDashboard(
            ingredients: cachedDashboardBaseIngredients,
            isLoading: showSkeleton,
            isPantryEmpty: pantryStore.ingredients.isEmpty,
            onReviewExpired: { sortOption = .expiration },
            onAddFirstItem: { session.requestedShowAddIngredient = true }
        )
    }

    // MARK: - Nav search

    private var searchResults: [Ingredient] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = query.isEmpty
            ? pantryStore.ingredients
            : pantryStore.ingredients.filter { $0.name.localizedCaseInsensitiveContains(query) }

        switch sortOption {
        case .expiration:
            return base.sorted { ($0.daysUntilExpiration ?? Int.max) < ($1.daysUntilExpiration ?? Int.max) }
        case .alphabetical:
            return base.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    private var searchNavBar: some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            Ph.magnifyingGlass.regular
                .frame(width: 18, height: 18)
                .foregroundStyle(Sourdough.Colors.faintInk)

            TextField("Search your pantry", text: $searchText)
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
        let results = searchResults

        if !query.isEmpty && results.isEmpty {
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
                ForEach(results) { item in
                    ingredientRow(item)
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

    private func activateSearch() {
        withAnimation(.easeInOut(duration: DS.Motion.normal)) { isSearchActive = true }
    }

    private func dismissSearch() {
        searchFocused = false
        withAnimation(.easeInOut(duration: DS.Motion.normal)) { isSearchActive = false }
        searchText = ""
    }

    @ViewBuilder
    private func ingredientRow(_ item: Ingredient) -> some View {
        ExpandableIngredientRow(
            item: item,
            onSelect: { selectedIngredient = item },
            onDelete: {
                if item.isExpired { activityStore.logEvent(type: .itemWasted) }
                withAnimation { pantryStore.deleteIngredient(id: item.id) }
            }
        )
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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

    // MARK: - Pantry List Header + Sort/Filter Controls

    private var pantryListHeader: some View {
        HStack {
            Text("Your Pantry")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.title2)

            Spacer()

            sortFilterRow
        }
    }

    private var sortFilterRow: some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            sortMenu
            filterButton
        }
    }

    private var itemCountRow: some View {
        let count = cachedFilteredIngredients.count
        return Text("\(count) item\(count == 1 ? "" : "s")")
            .foregroundStyle(Sourdough.Colors.mutedInk)
            .sourdoughTextStyle(.numeric)
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SortOption.allCases) { option in
                Button {
                    sortOption = option
                } label: {
                    Label {
                        Text(option.label)
                    } icon: {
                        if sortOption == option {
                            Ph.check.regular
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                Ph.arrowsDownUp.regular
                    .frame(width: 14, height: 14)
                Text("Sort")
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.subhead)
                Ph.caretDown.regular
                    .frame(width: 11, height: 11)
            }
            .foregroundStyle(Sourdough.Colors.mutedInk)
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .frame(height: 36)
            .background(Sourdough.Colors.sunken)
            .overlay(
                Capsule().stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
    }

    private var filterButton: some View {
        Button {
            showingFilterSheet = true
        } label: {
            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                Group {
                    if hasActiveFilters {
                        Ph.fadersHorizontal.fill
                    } else {
                        Ph.fadersHorizontal.regular
                    }
                }
                .frame(width: 14, height: 14)
                Text("Filter")
                    .foregroundStyle(hasActiveFilters ? Sourdough.Colors.onAction : Sourdough.Colors.ink)
                    .sourdoughTextStyle(.subhead)
            }
            .foregroundStyle(hasActiveFilters ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .frame(height: 36)
            .background(hasActiveFilters ? Sourdough.Ramp.sage500 : Sourdough.Colors.sunken)
            .overlay(
                Capsule().stroke(hasActiveFilters ? Color.clear : Sourdough.Colors.interactiveBorder, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private static let skeletonRowWidths: [(nameWidth: CGFloat, metaWidth: CGFloat)] = [
        (nameWidth: 120, metaWidth: 80),
        (nameWidth: 96,  metaWidth: 68),
        (nameWidth: 148, metaWidth: 90),
        (nameWidth: 108, metaWidth: 72),
        (nameWidth: 132, metaWidth: 76),
        (nameWidth: 88,  metaWidth: 64),
        (nameWidth: 116, metaWidth: 84),
    ]

    private var pantrySkeletonContent: some View {
        VStack(spacing: Sourdough.Spacing.insideChip) {
            ForEach(Self.skeletonRowWidths.indices, id: \.self) { index in
                PantrySkeletonRow(
                    nameWidth: Self.skeletonRowWidths[index].nameWidth,
                    metaWidth: Self.skeletonRowWidths[index].metaWidth
                )
            }
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.insideChip)
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

// MARK: - Skeleton Views

private struct PantrySkeletonRow: View {
    let nameWidth: CGFloat
    let metaWidth: CGFloat

    var body: some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous)
                .fill(Sourdough.Colors.sunken)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Sourdough.Colors.sunken)
                    .frame(width: nameWidth, height: 14)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Sourdough.Colors.sunken)
                    .frame(width: metaWidth, height: 11)
            }

            Spacer()

            RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                .fill(Sourdough.Colors.sunken)
                .frame(width: 48, height: 22)
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .frame(height: 72)
        .background(Sourdough.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
        .redacted(reason: .placeholder)
    }
}

private enum SortOption: CaseIterable, Identifiable {
    case expiration
    case alphabetical

    var id: Self { self }

    var label: String {
        switch self {
        case .expiration:   return "Expiration"
        case .alphabetical: return "Alphabetical"
        }
    }
}

private enum PantryCategory: String, CaseIterable, Identifiable {
    case proteins
    case seafood
    case produce
    case vegetables
    case carbs
    case dairy
    case fruits
    case condiments
    case other

    var id: String { rawValue }

    var label: String { ingredientCategory.title }
    var icon: Image {
        switch self {
        case .proteins:   return Ph.hamburger.regular
        case .seafood:    return Ph.fish.regular
        case .produce:    return Ph.carrot.regular
        case .vegetables: return Ph.leaf.regular
        case .carbs:      return Ph.cake.regular
        case .dairy:      return Ph.coffee.regular
        case .fruits:     return Ph.basket.regular
        case .condiments: return Ph.drop.regular
        case .other:      return Ph.dotsThreeCircle.regular
        }
    }

    var ingredientCategory: Ingredient.Category {
        switch self {
        case .proteins:   return .proteins
        case .seafood:    return .seafood
        case .produce:    return .produce
        case .vegetables: return .vegetables
        case .carbs:      return .carbs
        case .dairy:      return .dairy
        case .fruits:     return .fruits
        case .condiments: return .condiments
        case .other:      return .other
        }
    }

    func matches(ingredient: Ingredient) -> Bool {
        ingredient.category == ingredientCategory
    }
}

/// A single pantry ingredient card. Tapping presents `IngredientDetailSheet`; swiping from the
/// trailing edge deletes it (full swipe deletes instantly). Native `.swipeActions` is used
/// deliberately — a hand-rolled `DragGesture` on a row inside a `List` strands the scroll view's
/// pan recognizer after each touch, freezing scrolling until the next gesture.
struct ExpandableIngredientRow: View {
    let item: Ingredient
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        IngredientRowContent(item: item)
            .background(Sourdough.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .tint(Sourdough.Colors.destructive)
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

#Preview("Pantry") {
    PreviewContainer {
        NavigationStack {
            PantryView()
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

private struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var pantryStore: PantryStore
    @Binding var selectedStorageFilters: Set<IngredientStorageFilter>
    @Binding var selectedCategories: Set<PantryCategory>

    private var hasActiveFilters: Bool {
        !selectedStorageFilters.isEmpty || !selectedCategories.isEmpty
    }

    private var storageSummary: String {
        if let only = selectedStorageFilters.first, selectedStorageFilters.count == 1 {
            return only.label
        }
        return "All storage"
    }

    private var categorySummary: String {
        if selectedCategories.isEmpty {
            return "every category"
        }
        if let only = selectedCategories.first, selectedCategories.count == 1 {
            return only.label
        }
        return "\(selectedCategories.count) categories"
    }

    private var previewResultCount: Int {
        pantryStore.ingredients.filter { ingredient in
            let matchesCategory = selectedCategories.isEmpty || selectedCategories.contains { $0.matches(ingredient: ingredient) }
            let matchesStorage = selectedStorageFilters.isEmpty || selectedStorageFilters.contains { $0.matches(ingredient: ingredient) }
            return matchesCategory && matchesStorage
        }.count
    }

    private func categoryCount(_ category: PantryCategory) -> Int {
        pantryStore.ingredients.filter { category.matches(ingredient: $0) }.count
    }

    private func storageCount(_ filter: IngredientStorageFilter?) -> Int {
        guard let filter else { return pantryStore.ingredients.count }
        return pantryStore.ingredients.filter { filter.matches(ingredient: $0) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.betweenBlocks)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Sourdough.Spacing.betweenBlocks) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Filters")
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.title1)

                            Spacer()

                            if hasActiveFilters {
                                Button {
                                    selectedStorageFilters.removeAll()
                                    selectedCategories.removeAll()
                                } label: {
                                    Text("Clear")
                                        .foregroundStyle(Sourdough.Colors.actionInk)
                                        .sourdoughTextStyle(.caption)
                                        .padding(.horizontal, Sourdough.Spacing.rowInternals)
                                        .padding(.vertical, Sourdough.Spacing.insideChip)
                                        .overlay(
                                            Capsule()
                                                .stroke(Sourdough.Colors.actionInk, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("\(storageSummary) · \(categorySummary)")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.subhead)
                    }

                    // Storage section
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                        Text("STORAGE")
                            .foregroundStyle(Sourdough.Colors.faintInk)
                            .sourdoughTextStyle(.sectionHead)

                        filterGrid {
                            filterCard(
                                icon: nil,
                                label: "All",
                                count: storageCount(nil),
                                isSelected: selectedStorageFilters.isEmpty
                            ) {
                                selectedStorageFilters.removeAll()
                            }
                            ForEach(IngredientStorageFilter.allCases) { filter in
                                filterCard(
                                    icon: filter.icon,
                                    label: filter.label,
                                    count: storageCount(filter),
                                    isSelected: selectedStorageFilters.contains(filter)
                                ) {
                                    selectedStorageFilters = [filter]
                                }
                            }
                        }
                    }

                    // Category section
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                        Text("CATEGORY")
                            .foregroundStyle(Sourdough.Colors.faintInk)
                            .sourdoughTextStyle(.sectionHead)

                        filterGrid {
                            ForEach(PantryCategory.allCases) { category in
                                filterCard(
                                    icon: category.icon,
                                    label: category.label,
                                    count: categoryCount(category),
                                    isSelected: selectedCategories.contains(category)
                                ) {
                                    toggleSet(&selectedCategories, category)
                                }
                            }
                        }
                    }

                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            Button {
                dismiss()
            } label: {
                HStack {
                    Text("Apply filters")
                        .foregroundStyle(Sourdough.Colors.onAction)
                        .sourdoughTextStyle(.rowTitle)

                    Spacer()

                    let count = previewResultCount
                    Text("\(count) item\(count == 1 ? "" : "s")")
                        .foregroundStyle(Sourdough.Colors.onAction)
                        .sourdoughTextStyle(.numeric)
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Sourdough.Colors.action)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.betweenBlocks)
        }
    }

    @ViewBuilder
    private func filterGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals),
                GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals)
            ],
            spacing: Sourdough.Spacing.rowInternals,
            content: content
        )
    }

    private func filterCard(
        icon: Image?,
        label: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                if let icon {
                    icon
                        .frame(width: 18, height: 18)
                        .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.ink)
                        .sourdoughTextStyle(.rowTitle)

                    Text("\(count) item\(count == 1 ? "" : "s")")
                        .foregroundStyle(isSelected ? Sourdough.Colors.onAction.opacity(0.85) : Sourdough.Colors.faintInk)
                        .sourdoughTextStyle(.caption)
                }

                Spacer(minLength: 0)
            }
            .padding(Sourdough.Spacing.rowInternals)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                    .stroke(isSelected ? Color.clear : Sourdough.Colors.interactiveBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Extend Expiration Sheet

