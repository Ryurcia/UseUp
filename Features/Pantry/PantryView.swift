import SwiftUI
import PhosphorSwift

struct PantryView: View {
    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var activityStore: UserActivityStore

    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var selectedCategories: Set<PantryCategory> = []
    @State private var selectedStorageFilters: Set<IngredientStorageFilter> = []
    @State private var selectedFreshnessTier: FreshnessTier? = nil
    @State private var sortOption: SortOption = .expiration
    @State private var showingAddSheet = false
    @State private var showingFilterSheet = false
    @State private var showingSettings = false
    @State private var ingredientPendingDelete: Ingredient?
    @State private var ingredientBeingEdited: Ingredient?
    @State private var ingredientBeingUsed: Ingredient?
    @State private var selectedIngredient: Ingredient?
    @State private var cachedFilteredIngredients: [Ingredient] = []
    @State private var cachedDashboardBaseIngredients: [Ingredient] = []
    @State private var visibleCount = PantryView.pageSize
    @State private var pendingIngredient: PendingIngredient? = nil
    @State private var duplicateExisting: Ingredient? = nil
    @State private var showDuplicateAlert = false
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

    private func recomputeFilteredIngredients() {
        // Search + category + storage applied, but *not* the freshness-tier filter — this is the
        // base set the dashboard computes its counts from, so selecting a tier never changes the
        // counts shown for the other tiers. Cached (like cachedFilteredIngredients below) so it's
        // computed once per relevant change rather than on every body evaluation.
        let dashboardBase = pantryStore.ingredients.filter { ingredient in
            let trimmedSearch = debouncedSearch.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = trimmedSearch.isEmpty || ingredient.name.localizedCaseInsensitiveContains(trimmedSearch)
            let matchesCategory = selectedCategories.isEmpty || selectedCategories.contains { $0.matches(ingredient: ingredient) }
            let matchesStorage = selectedStorageFilters.isEmpty || selectedStorageFilters.contains { $0.matches(ingredient: ingredient) }
            return matchesSearch && matchesCategory && matchesStorage
        }
        cachedDashboardBaseIngredients = dashboardBase

        let filtered = dashboardBase.filter { ingredient in
            guard let tier = selectedFreshnessTier else { return true }
            return tier.matches(ingredient.freshnessState)
        }

        switch sortOption {
        case .expiration:
            cachedFilteredIngredients = filtered.sorted {
                ($0.daysUntilExpiration ?? Int.max) < ($1.daysUntilExpiration ?? Int.max)
            }
        case .alphabetical:
            cachedFilteredIngredients = filtered.sorted {
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
            .onChange(of: searchText) { _, newValue in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    debouncedSearch = newValue
                }
            }
            .onChange(of: debouncedSearch) { _, _ in recomputeFilteredIngredients() }
            .onChange(of: selectedCategories) { _, _ in recomputeFilteredIngredients() }
            .onChange(of: selectedStorageFilters) { _, _ in recomputeFilteredIngredients() }
            .onChange(of: selectedFreshnessTier) { _, _ in recomputeFilteredIngredients() }
            .onChange(of: sortOption) { _, _ in recomputeFilteredIngredients() }
            .onChange(of: pantryStore.ingredients) { _, _ in recomputeFilteredIngredients() }
    }

    private var withSheets: some View {
        withOverlays
            .sheet(isPresented: $showingAddSheet) {
                AddIngredientSheet { name, amount, category, location, expirationDate, icon in
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if let existing = pantryStore.ingredients.first(where: { $0.name.lowercased() == trimmed }) {
                        pendingIngredient = PendingIngredient(name: name, amount: amount, category: category,
                                                              location: location, expirationDate: expirationDate, icon: icon)
                        duplicateExisting = existing
                        showDuplicateAlert = true
                    } else {
                        withAnimation {
                            pantryStore.addIngredient(name: name, amount: amount, category: category,
                                                      location: location, expirationDate: expirationDate, icon: icon)
                        }
                    }
                }
            }
            .sheet(item: $ingredientBeingEdited) { ingredient in
                EditIngredientSheet(ingredient: ingredient) { name, amount, category, location, expirationDate, icon in
                    withAnimation {
                        pantryStore.updateIngredient(
                            id: ingredient.id, name: name, amount: amount,
                            category: category, location: location, expirationDate: expirationDate, icon: icon
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
                    }
                )
                .presentationDetents([.height(430)])
                .presentationDragIndicator(.hidden)
            }
            .alert("Already in Your Pantry", isPresented: $showDuplicateAlert, presenting: duplicateExisting) { existing in
                Button("Edit Existing") {
                    ingredientBeingEdited = existing
                    pendingIngredient = nil
                    duplicateExisting = nil
                }
                Button("Save as New") {
                    if let p = pendingIngredient {
                        withAnimation {
                            pantryStore.addIngredient(name: p.name, amount: p.amount, category: p.category,
                                                      location: p.location, expirationDate: p.expirationDate,
                                                      icon: p.icon, force: true)
                        }
                    }
                    pendingIngredient = nil
                    duplicateExisting = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingIngredient = nil
                    duplicateExisting = nil
                }
            } message: { existing in
                Text("\(existing.name.capitalized) is already logged in your pantry.")
            }
            .alert("Delete ingredient?", isPresented: isShowingDeleteAlert, presenting: ingredientPendingDelete) { ingredient in
                Button("Cancel", role: .cancel) { ingredientPendingDelete = nil }
                Button("Delete", role: .destructive) {
                    if ingredient.isExpired { activityStore.logEvent(type: .itemWasted) }
                    withAnimation { pantryStore.deleteIngredient(id: ingredient.id) }
                    ingredientPendingDelete = nil
                }
            } message: { ingredient in
                Text("This will remove \(ingredient.name.capitalized) from your pantry.")
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(
                    selectedStorageFilters: $selectedStorageFilters,
                    selectedCategories: $selectedCategories
                )
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingSettings) {
                NavigationStack { SettingsView() }
                    .preferredColorScheme(session.preferredColorScheme)
            }
    }

    private var withOverlays: some View {
        mainContent
            .background(Sourdough.Colors.canvas)
            .overlay { dimBackground }
            .overlay(alignment: .bottomTrailing) { fabButton }
            .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private var dimBackground: some View {
        if showingAddSheet || showingFilterSheet || showingSettings || ingredientBeingEdited != nil || ingredientBeingUsed != nil || selectedIngredient != nil {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.2), value: showingAddSheet)
                .animation(.easeInOut(duration: 0.2), value: showingFilterSheet)
                .animation(.easeInOut(duration: 0.2), value: showingSettings)
                .animation(.easeInOut(duration: 0.2), value: ingredientBeingEdited != nil)
                .animation(.easeInOut(duration: 0.2), value: ingredientBeingUsed != nil)
                .animation(.easeInOut(duration: 0.2), value: selectedIngredient != nil)
        }
    }

    private var fabButton: some View {
        Button { showingAddSheet = true } label: {
            Ph.plus.bold
                .frame(width: 24, height: 24)
                .foregroundStyle(Sourdough.Colors.onAction)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(Sourdough.Colors.action)
                        .shadow(color: Sourdough.Ramp.linen900.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .padding(.trailing, Sourdough.Spacing.screenMargin)
        .padding(.bottom, 90)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerView

            PantryFreshnessDashboard(
                ingredients: cachedDashboardBaseIngredients,
                isLoading: showSkeleton,
                isPantryEmpty: pantryStore.ingredients.isEmpty,
                selectedTier: $selectedFreshnessTier,
                onReviewExpired: { sortOption = .expiration },
                onAddFirstItem: { showingAddSheet = true }
            )
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.betweenBlocks)

            searchBar
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.rowInternals)

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
                            ExpandableIngredientRow(
                                item: item,
                                onSelect: { selectedIngredient = item },
                                onDelete: { ingredientPendingDelete = item }
                            )
                            .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
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
    }

    private var headerView: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            HStack(spacing: Sourdough.Spacing.screenMargin) {
                Text("Today is \(Date.now, format: .dateTime.month(.wide).day())")
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.subhead)

                Spacer()

                Button {
                    showingSettings = true
                } label: {
                    Ph.gear.regular
                        .frame(width: 22, height: 22)
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                }
                .buttonStyle(.plain)

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

    private var searchBar: some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            Ph.magnifyingGlass.regular
                .frame(width: 18, height: 18)
                .foregroundStyle(Sourdough.Colors.faintInk)

            TextField("Search your pantry", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.body)
        }
        .padding(.horizontal, Sourdough.Spacing.rowInternals)
        .frame(height: 48)
        .background(Sourdough.Colors.sunken)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
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

    private var isShowingDeleteAlert: Binding<Bool> {
        Binding(
            get: { ingredientPendingDelete != nil },
            set: { isPresented in
                if !isPresented {
                    ingredientPendingDelete = nil
                }
            }
        )
    }
}

// MARK: - Pending Ingredient (duplicate flow)

private struct PendingIngredient {
    let name: String
    let amount: String?
    let category: Ingredient.Category
    let location: Ingredient.StorageLocation
    let expirationDate: Date?
    let icon: String?
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
                    if let amount = item.amount, !amount.isEmpty {
                        Text(amount)
                        Text("·")
                    }
                    Text(item.location.title)
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

/// The 3 selectable tiers driving the freshness dashboard's legend chips/bar segments — deliberately
/// excludes `.expired` (surfaced separately as "N expired · review", not a selectable tier) and treats
/// undated items as out of scope entirely (see `PantryFreshnessDashboard`).
enum FreshnessTier: CaseIterable, Identifiable {
    case fresh
    case soon
    case urgent

    var id: Self { self }

    func matches(_ state: Sourdough.FreshnessState) -> Bool {
        switch self {
        case .fresh:  return state == .fresh
        case .soon:   return state == .soon
        case .urgent: return state == .urgent
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

/// A single pantry ingredient card. Tapping presents `IngredientDetailSheet`; swiping reveals delete.
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
            .swipeActions(edge: .trailing) {
                Button(role: .destructive, action: onDelete) {
                    Label {
                        Text("Delete")
                    } icon: {
                        Image(systemName: "trash")
                    }
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

    private var state: Sourdough.FreshnessState { item.freshnessState }

    private var statusLabel: String {
        switch state {
        case .expired: return "Expired"
        case .urgent:  return "Use today"
        case .soon:    return "Expiring soon"
        case .fresh:   return "Fresh"
        }
    }

    /// Ink-safe accent per state, for text sitting directly on the plain canvas/card — distinct from
    /// `FreshnessStyle.label`, which assumes it's drawn on top of the matching chip fill (e.g. `.urgent`'s
    /// label is near-white, correct on a solid terracotta chip but unreadable on a plain background).
    private var statusColor: Color {
        switch state {
        case .expired: return Sourdough.Colors.destructive
        case .urgent:  return Sourdough.Colors.actionInk
        case .soon:    return Sourdough.Ramp.honey700
        case .fresh:   return Sourdough.Ramp.sage600
        }
    }

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
                detailRow(label: "Location", value: item.location.title)
                detailRow(label: "Category", value: item.category.title)
                detailRow(
                    label: "Expires",
                    value: item.expirationDate.map(IngredientRowContent.formatExpiration) ?? "—",
                    valueColor: item.expirationDate != nil ? statusColor : nil
                )
            }
            .padding(.top, Sourdough.Spacing.betweenBlocks)

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

private struct AddIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: AppSession

    @State private var name = ""
    @State private var amountValue = ""
    @State private var unit: UnitMeasurement = .none
    @State private var category: Ingredient.Category = .other
    @State private var location: Ingredient.StorageLocation = .fridge
    @State private var hasExpiration = false
    @State private var expirationDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var icon: String? = nil
    @State private var showBarcodeScanner = false
    @State private var showPaywall = false
    @State private var showSpeechRecording = false
    @State private var speechPermissionDenied = false

    let onSave: (String, String?, Ingredient.Category, Ingredient.StorageLocation, Date?, String?) -> Void

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !amountValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var formattedAmount: String? {
        let trimmed = amountValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return unit == .none ? trimmed : "\(trimmed) \(unit.label)"
    }

    var body: some View {
        IngredientFormContent(
            title: "Add Ingredient",
            name: $name,
            amountValue: $amountValue,
            unit: $unit,
            category: $category,
            location: $location,
            hasExpiration: $hasExpiration,
            expirationDate: $expirationDate,
            icon: $icon,
            canSave: canSave,
            saveLabel: "Add Ingredient",
            onCancel: { dismiss() },
            onSave: {
                onSave(name, formattedAmount, category, location, hasExpiration ? expirationDate : nil, icon)
                dismiss()
            },
            onSpeechTap: {
                guard session.isPremium else { showPaywall = true; return }
                if #available(iOS 26, *) {
                    Task {
                        let granted = await SpeechIngredientRecognizer.requestPermissions()
                        if granted { showSpeechRecording = true } else { speechPermissionDenied = true }
                    }
                }
            },
            onBarcodeTap: {
                if session.isPremium { showBarcodeScanner = true } else { showPaywall = true }
            }
        )
        .fullScreenCover(isPresented: $showBarcodeScanner) {
            BarcodeScannerSheet { productName, rawQuantity, productCategory, capturedExpDate in
                name = productName
                let parsed = UnitMeasurement.parse(from: rawQuantity)
                amountValue = parsed.value
                unit = parsed.unit
                if let cat = productCategory { category = cat }
                if let d = capturedExpDate {
                    hasExpiration = true
                    expirationDate = d
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            UseUpPaywallView(onDismiss: { showPaywall = false })
        }
        .sheet(isPresented: $showSpeechRecording) {
            if #available(iOS 26, *) {
                SpeechRecordingSheet { spokenName, rawQuantity in
                    name = spokenName
                    if !rawQuantity.isEmpty {
                        let parsed = UnitMeasurement.parse(from: rawQuantity)
                        amountValue = parsed.value
                        unit = parsed.unit
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

struct EditIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss

    let ingredient: Ingredient
    let onSave: (String, String?, Ingredient.Category, Ingredient.StorageLocation, Date?, String?) -> Void

    @State private var name: String
    @State private var amountValue: String
    @State private var unit: UnitMeasurement
    @State private var category: Ingredient.Category
    @State private var location: Ingredient.StorageLocation
    @State private var hasExpiration: Bool
    @State private var expirationDate: Date
    @State private var icon: String?

    init(
        ingredient: Ingredient,
        onSave: @escaping (String, String?, Ingredient.Category, Ingredient.StorageLocation, Date?, String?) -> Void
    ) {
        self.ingredient = ingredient
        self.onSave = onSave
        _name = State(initialValue: ingredient.name)

        let parsed = UnitMeasurement.parse(from: ingredient.amount)
        _amountValue = State(initialValue: parsed.value)
        _unit = State(initialValue: parsed.unit)

        _category = State(initialValue: ingredient.category)
        _location = State(initialValue: ingredient.location)
        _hasExpiration = State(initialValue: ingredient.expirationDate != nil)
        _expirationDate = State(initialValue: ingredient.expirationDate ?? Date())
        _icon = State(initialValue: ingredient.icon)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !amountValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var formattedAmount: String? {
        let trimmed = amountValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return unit == .none ? trimmed : "\(trimmed) \(unit.label)"
    }

    var body: some View {
        IngredientFormContent(
            title: "Edit Ingredient",
            name: $name,
            amountValue: $amountValue,
            unit: $unit,
            category: $category,
            location: $location,
            hasExpiration: $hasExpiration,
            expirationDate: $expirationDate,
            icon: $icon,
            canSave: canSave,
            saveLabel: "Save Changes",
            onCancel: { dismiss() },
            onSave: {
                onSave(name, formattedAmount, category, location, hasExpiration ? expirationDate : nil, icon)
                dismiss()
            }
        )
    }
}

// MARK: - Shared Ingredient Form

private struct IngredientFormContent: View {
    let title: String
    @Binding var name: String
    @Binding var amountValue: String
    @Binding var unit: UnitMeasurement
    @Binding var category: Ingredient.Category
    @Binding var location: Ingredient.StorageLocation
    @Binding var hasExpiration: Bool
    @Binding var expirationDate: Date
    @Binding var icon: String?
    let canSave: Bool
    let saveLabel: String
    let onCancel: () -> Void
    let onSave: () -> Void
    var onSpeechTap: (() -> Void)? = nil
    var onBarcodeTap: (() -> Void)? = nil

    static let foodEmojis: [String] = [
        "🍎", "🍊", "🍋", "🍇", "🍓", "🫐", "🍑", "🍒", "🍍", "🥭",
        "🍌", "🍉", "🍐", "🥝", "🍅", "🫒",
        "🥕", "🥦", "🧅", "🧄", "🥬", "🌽", "🫑", "🥒", "🥑", "🍆",
        "🌶️", "🥔",
        "🥩", "🍗", "🍖", "🥚", "🫘", "🥜", "🍳",
        "🐟", "🦐", "🦑", "🦞", "🦀", "🐙", "🦪",
        "🥛", "🧀", "🧈",
        "🍞", "🥐", "🥨", "🥞", "🧇", "🍚", "🍜", "🍝", "🫓", "🌾",
        "🫙", "🧂", "🍯", "🫕", "🫚",
        "🍄", "🌰", "🥗", "🧊", "🧃",
    ]

    @State private var showingIconPicker = false

    private var trailingPadding: CGFloat {
        let hasSpeech = onSpeechTap != nil
        let hasBarcode = onBarcodeTap != nil
        let iconCount = (hasSpeech ? 1 : 0) + (hasBarcode ? 1 : 0)
        guard iconCount > 0 else { return Sourdough.Spacing.screenMargin }
        return Sourdough.Spacing.screenMargin + CGFloat(iconCount) * 28 + CGFloat(iconCount - 1) * 16
    }

    private func storageIcon(for loc: Ingredient.StorageLocation) -> Image {
        switch loc {
        case .fridge: return Ph.doorOpen.regular
        case .freezer: return Ph.snowflake.regular
        case .pantry: return Ph.archive.regular
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle + header
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.insideChip)

            HStack {
                Text(title)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.title1)
                Spacer()
                Button("Cancel", action: onCancel)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.caption)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.rowInternals)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Sourdough.Spacing.betweenBlocks) {
                    // Icon + Name field
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                        // Icon selector centered above the name field
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                showingIconPicker.toggle()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Sourdough.Colors.sunken)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                showingIconPicker ? Sourdough.Ramp.sage500 : Sourdough.Colors.interactiveBorder,
                                                lineWidth: showingIconPicker ? 2 : 1
                                            )
                                    )
                                    .frame(width: 80, height: 80)
                                Text(icon ?? category.icon)
                                    .font(.system(size: 40))
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, Sourdough.Spacing.iconToLabel)

                        Text("Ingredient Name")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)

                        // Text field with scan/speech icons inside trailing edge
                        ZStack(alignment: .trailing) {
                            TextField("e.g. Chicken breast", text: $name)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.body)
                                .padding(.leading, Sourdough.Spacing.screenMargin)
                                .padding(.trailing, trailingPadding)
                                .frame(height: 48)
                                .background(Sourdough.Colors.sunken)
                                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                            HStack(spacing: Sourdough.Spacing.screenMargin) {
                                if #available(iOS 26, *), let onSpeechTap {
                                    Button(action: onSpeechTap) {
                                        Ph.microphone.regular
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(Sourdough.Colors.actionInk)
                                    }
                                    .buttonStyle(.plain)
                                }
                                if let onBarcodeTap {
                                    Button(action: onBarcodeTap) {
                                        Ph.barcode.regular
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(Sourdough.Colors.actionInk)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.trailing, Sourdough.Spacing.screenMargin)
                        }

                        if showingIconPicker {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                                spacing: 4
                            ) {
                                ForEach(IngredientFormContent.foodEmojis, id: \.self) { emoji in
                                    Button {
                                        icon = icon == emoji ? nil : emoji
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 24))
                                            .frame(width: 44, height: 44)
                                            .background(icon == emoji ? Sourdough.Ramp.sage500.opacity(0.15) : Color.clear)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous)
                                                    .stroke(icon == emoji ? Sourdough.Ramp.sage500 : Color.clear, lineWidth: 1.5)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    // Amount field
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                        Text("Amount")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)

                        HStack(spacing: Sourdough.Spacing.insideChip) {
                            TextField("e.g. 500", text: $amountValue)
                                .keyboardType(.decimalPad)
                                .onChange(of: amountValue) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    if filtered != newValue { amountValue = filtered }
                                }
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.body)
                                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                                .frame(height: 48)
                                .background(Sourdough.Colors.sunken)
                                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                            Menu {
                                ForEach(UnitMeasurement.allCases) { u in
                                    Button {
                                        unit = u
                                    } label: {
                                        HStack {
                                            Text(u.displayName)
                                            if unit == u {
                                                Ph.check.regular.frame(width: 16, height: 16)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: Sourdough.Spacing.iconToLabel) {
                                    Text(unit.label.isEmpty ? "Unit" : unit.label)
                                        .foregroundStyle(
                                            unit == .none
                                                ? Sourdough.Colors.faintInk
                                                : Sourdough.Colors.ink
                                        )
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
                        }
                    }

                    // Category
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                        Text("Category")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: Sourdough.Spacing.insideChip),
                            GridItem(.flexible(), spacing: Sourdough.Spacing.insideChip),
                            GridItem(.flexible(), spacing: Sourdough.Spacing.insideChip)
                        ], spacing: Sourdough.Spacing.insideChip) {
                            ForEach(Ingredient.Category.allCases) { cat in
                                Button {
                                    category = cat
                                } label: {
                                    HStack(spacing: Sourdough.Spacing.iconToLabel) {
                                        Text(cat.icon)
                                            .font(.system(size: 18))
                                        Text(cat.title)
                                            .foregroundStyle(
                                                category == cat ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk
                                            )
                                            .sourdoughTextStyle(.caption)
                                    }
                                    .foregroundStyle(
                                        category == cat ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(
                                        category == cat
                                            ? Sourdough.Ramp.sage500
                                            : Sourdough.Colors.sunken
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                                            .stroke(
                                                category == cat
                                                    ? Color.clear
                                                    : Sourdough.Colors.interactiveBorder,
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Storage location
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                        Text("Storage Location")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)

                        HStack(spacing: Sourdough.Spacing.insideChip) {
                            ForEach(Ingredient.StorageLocation.allCases) { loc in
                                Button {
                                    location = loc
                                } label: {
                                    HStack(spacing: Sourdough.Spacing.insideChip) {
                                        storageIcon(for: loc)
                                            .frame(width: 14, height: 14)
                                        Text(loc.title)
                                            .foregroundStyle(
                                                location == loc ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk
                                            )
                                            .sourdoughTextStyle(.caption)
                                    }
                                    .foregroundStyle(
                                        location == loc ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        location == loc
                                            ? Sourdough.Ramp.sage500
                                            : Sourdough.Colors.sunken
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                                            .stroke(
                                                location == loc
                                                    ? Color.clear
                                                    : Sourdough.Colors.interactiveBorder,
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Expiration
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                        Text("Expiration Date")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)

                        HStack {
                            Text("Has expiration date")
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.body)

                            Spacer()

                            Toggle("", isOn: $hasExpiration.animation(DS.Motion.easeOut))
                                .labelsHidden()
                                .tint(Sourdough.Ramp.sage500)
                        }
                        .padding(.horizontal, Sourdough.Spacing.rowInternals)
                        .frame(height: 48)
                        .background(Sourdough.Colors.sunken)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                        if hasExpiration {
                            DatePicker(
                                "",
                                selection: $expirationDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(Sourdough.Ramp.sage500)
                            .padding(.horizontal, Sourdough.Spacing.insideChip)
                            .background(Sourdough.Colors.sunken)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }
            .scrollDismissesKeyboard(.immediately)

            VStack(spacing: Sourdough.Spacing.rowInternals) {
                Button(action: onSave) {
                    Text(saveLabel)
                        .foregroundStyle(Sourdough.Colors.onAction)
                        .sourdoughTextStyle(.rowTitle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canSave ? Sourdough.Colors.action : Sourdough.Colors.action.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.rowInternals)
            .background(
                LinearGradient(
                    colors: [Sourdough.Colors.canvas.opacity(0), Sourdough.Colors.canvas],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .background(Sourdough.Colors.canvas)
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
        let p = QuantityConverter.parse(ingredient.amount ?? "")
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
        return "Not enough — only \(ingredient.amount ?? "") / \(availInUsageUnit) \(usageUnit.label) available"
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

                    if let amount = ingredient.amount, !amount.isEmpty {
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

// MARK: - Unit Measurement

private enum UnitMeasurement: String, CaseIterable, Identifiable {
    case none
    case g
    case kg
    case oz
    case floz
    case lb
    case ml
    case l
    case cups
    case tbsp
    case tsp
    case pieces

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return ""
        case .g: return "g"
        case .kg: return "kg"
        case .oz: return "oz"
        case .floz: return "fl oz"
        case .lb: return "lb"
        case .ml: return "ml"
        case .l: return "L"
        case .cups: return "cups"
        case .tbsp: return "tbsp"
        case .tsp: return "tsp"
        case .pieces: return "pcs"
        }
    }

    var displayName: String {
        switch self {
        case .none: return "No unit"
        case .g: return "Grams (g)"
        case .kg: return "Kilograms (kg)"
        case .oz: return "Ounces (oz)"
        case .floz: return "Fluid Ounces (fl oz)"
        case .lb: return "Pounds (lb)"
        case .ml: return "Milliliters (ml)"
        case .l: return "Liters (L)"
        case .cups: return "Cups"
        case .tbsp: return "Tablespoons (tbsp)"
        case .tsp: return "Teaspoons (tsp)"
        case .pieces: return "Pieces (pcs)"
        }
    }

    static func parse(from amount: String?) -> (value: String, unit: UnitMeasurement) {
        guard let amount, !amount.isEmpty else { return ("", .none) }

        let sorted = UnitMeasurement.allCases.filter { $0 != .none }
            .sorted { $0.label.count > $1.label.count }
        for u in sorted {
            if amount.hasSuffix(" \(u.label)") {
                let value = String(amount.dropLast(u.label.count + 1))
                return (value, u)
            }
        }

        return (amount, .none)
    }
}

@available(iOS 26, *)
private struct SpeechRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onResult: (String, String) -> Void

    @State private var recognizer = SpeechIngredientRecognizer()
    @State private var liveTranscript = ""
    @State private var ring1 = false
    @State private var ring2 = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.aboveSectionHead)

            Spacer()

            // Ripple animation + mic icon
            ZStack {
                Circle()
                    .stroke(Sourdough.Colors.action.opacity(0.25), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .scaleEffect(ring1 ? 2.4 : 1.0)
                    .opacity(ring1 ? 0 : 1)

                Circle()
                    .stroke(Sourdough.Colors.action.opacity(0.25), lineWidth: 2)
                    .frame(width: 100, height: 100)
                    .scaleEffect(ring2 ? 2.4 : 1.0)
                    .opacity(ring2 ? 0 : 1)

                Circle()
                    .fill(Sourdough.Colors.action.opacity(0.1))
                    .frame(width: 100, height: 100)

                Ph.microphone.regular
                    .frame(width: 36, height: 36)
                    .foregroundStyle(Sourdough.Colors.action)
            }
            .frame(width: 160, height: 160)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    ring1 = true
                }
                withAnimation(.easeOut(duration: 1.5).delay(0.75).repeatForever(autoreverses: false)) {
                    ring2 = true
                }
            }

            Text("Speak clearly and concisely")
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.subhead)
                .padding(.top, Sourdough.Spacing.rowInternals)

            Text(liveTranscript.isEmpty ? "Listening…" : liveTranscript)
                .foregroundStyle(liveTranscript.isEmpty ? Sourdough.Colors.faintInk : Sourdough.Colors.ink)
                .sourdoughTextStyle(.body)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.aboveSectionHead)
                .animation(DS.Motion.easeDefault, value: liveTranscript)

            Spacer()

            Button { stopAndDismiss() } label: {
                Text("Stop")
                    .foregroundStyle(Sourdough.Colors.onDestructive)
                    .sourdoughTextStyle(.rowTitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Sourdough.Colors.destructive)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.rowInternals)
        }
        .background(Sourdough.Colors.canvas)
        .task {
            recognizer.onUpdate = { text in liveTranscript = text }
            recognizer.onFinal = { text in
                let parsed = SpeechIngredientRecognizer.parseIngredient(from: text)
                onResult(parsed.name, parsed.quantity)
                dismiss()
            }
            try? recognizer.start()
        }
        .onDisappear { recognizer.stop() }
    }

    private func stopAndDismiss() {
        let lastTranscript = liveTranscript
        recognizer.onFinal = nil
        recognizer.stop()
        if !lastTranscript.isEmpty {
            let parsed = SpeechIngredientRecognizer.parseIngredient(from: lastTranscript)
            onResult(parsed.name, parsed.quantity)
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

