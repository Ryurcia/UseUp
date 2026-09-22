import SwiftUI
import UIKit
import PhosphorSwift

/// The dedicated Pantry tab — search bar + All/Pantry/Fridge/Freezer pill filters + a single flat,
/// paginated ingredient list. Replaces the earlier 3-card location-carousel design (which pushed
/// into a separate `LocationDetailView`); that screen's search/sort/filter/pagination logic has
/// been folded directly into this one, flattened (no more "Expiring Soon"/"Still Good" sections).
struct PantryView: View {
    var isActiveTab: Bool = true
    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var activityStore: UserActivityStore
    @EnvironmentObject private var session: AppSession

    @State private var selectedLocation: Ingredient.StorageLocation?
    @State private var selectedCategories: Set<PantryCategory> = []
    @State private var sortOption: SortOption = .expiration
    @State private var searchText = ""
    @State private var showingFilterSheet = false

    @State private var selectedIngredient: Ingredient?
    @State private var ingredientBeingEdited: Ingredient?
    @State private var ingredientBeingUsed: Ingredient?

    @State private var visibleCount = 20
    private static let pageSize = 20

    private var showSkeleton: Bool {
        pantryStore.isLoading && pantryStore.ingredients.isEmpty
    }

    private var hasActiveFilters: Bool { !selectedCategories.isEmpty }

    private var pillFilteredIngredients: [Ingredient] {
        pantryStore.ingredients.filter { selectedLocation == nil || $0.location == selectedLocation }
    }

    private var filteredIngredients: [Ingredient] {
        let categoryFiltered = pillFilteredIngredients.filter { ingredient in
            selectedCategories.isEmpty || selectedCategories.contains { $0.matches(ingredient: ingredient) }
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searched = query.isEmpty
            ? categoryFiltered
            : categoryFiltered.filter { $0.name.localizedCaseInsensitiveContains(query) }

        switch sortOption {
        case .expiration:
            return searched.sorted { ($0.daysUntilExpiration ?? Int.max) < ($1.daysUntilExpiration ?? Int.max) }
        case .alphabetical:
            return searched.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            searchBar
            pillFilterRow

            if showSkeleton {
                skeletonList
            } else if pillFilteredIngredients.isEmpty {
                emptyState
            } else {
                ingredientList
            }
        }
        .background(Sourdough.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingFilterSheet) {
            PantryCategoryFilterSheet(selectedCategories: $selectedCategories, pantryStore: pantryStore, baseIngredients: pillFilteredIngredients)
                .presentationDetents([.large])
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
                onQuickGenerate: { selectedIngredient = nil }
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(item: $ingredientBeingUsed) { ingredient in
            UseIngredientSheet(ingredient: ingredient) { newAmount in
                withAnimation { pantryStore.useIngredient(id: ingredient.id, newAmount: newAmount) }
                if newAmount == nil { activityStore.logEvent(type: .itemSaved) }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $ingredientBeingEdited) { ingredient in
            EditIngredientSheet(ingredient: ingredient) { name, amount, unitCount, quantityEstimate, quantitySource, category, location, expirationDate, icon in
                withAnimation {
                    pantryStore.updateIngredient(
                        id: ingredient.id, name: name, amount: amount, unitCount: unitCount,
                        quantityEstimate: quantityEstimate, quantitySource: quantitySource,
                        category: category, location: location, expirationDate: expirationDate, icon: icon,
                        estimatedTotalCost: ingredient.estimatedTotalCost
                    )
                }
            } onMedicationDetected: {
                withAnimation { pantryStore.deleteIngredient(id: ingredient.id) }
            }
        }
        .onChange(of: selectedLocation) { _, _ in visibleCount = Self.pageSize }
        .onChange(of: selectedCategories) { _, _ in visibleCount = Self.pageSize }
        .onChange(of: searchText) { _, _ in visibleCount = Self.pageSize }
        .onChange(of: session.requestedPantryLocation, initial: true) { _, location in
            guard isActiveTab, let location else { return }
            withAnimation(.easeInOut(duration: DS.Motion.fast)) { selectedLocation = location }
            session.requestedPantryLocation = nil
        }
        .task(id: isActiveTab) {
            guard isActiveTab else { return }
            if let location = session.requestedPantryLocation {
                selectedLocation = location
                session.requestedPantryLocation = nil
            }
            await pantryStore.fetchIngredients()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: Sourdough.Spacing.screenMargin) {
            Text("Pantry")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.title1)
            Spacer()
            NotificationBellButton()
            ProfileNavButton()
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.iconToLabel)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            Ph.magnifyingGlass.regular
                .frame(width: 18, height: 18)
                .foregroundStyle(Sourdough.Colors.faintInk)

            TextField("Search \(selectedLocation?.title ?? "Pantry")", text: $searchText)
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
        }
        .padding(.horizontal, Sourdough.Spacing.rowInternals)
        .frame(height: 48)
        .background(Sourdough.Colors.sunken)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
    }

    // MARK: - Pills + Sort/Filter

    private var pillFilterRow: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Sourdough.Spacing.insideChip) {
                    SelectableChip(
                        label: "All · \(pantryStore.ingredients.count)",
                        isSelected: selectedLocation == nil,
                        size: .medium
                    ) {
                        withAnimation(.easeInOut(duration: DS.Motion.fast)) { selectedLocation = nil }
                    }
                    ForEach(Ingredient.StorageLocation.allCases) { loc in
                        SelectableChip(
                            label: "\(loc.title) · \(pantryStore.count(in: loc))",
                            isSelected: selectedLocation == loc,
                            size: .medium
                        ) {
                            withAnimation(.easeInOut(duration: DS.Motion.fast)) { selectedLocation = loc }
                        }
                    }
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            HStack(spacing: Sourdough.Spacing.insideChip) {
                Spacer(minLength: 0)
                sortMenu
                filterButton
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
        }
        .padding(.bottom, Sourdough.Spacing.rowInternals)
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
                        if sortOption == option { Ph.check.regular }
                    }
                }
            }
        } label: {
            Ph.arrowsDownUp.regular
                .frame(width: 14, height: 14)
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .frame(width: 36, height: 36)
                .background(Sourdough.Colors.sunken)
                .overlay(Circle().stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1))
                .clipShape(Circle())
        }
    }

    private var filterButton: some View {
        Button {
            showingFilterSheet = true
        } label: {
            Group {
                if hasActiveFilters { Ph.fadersHorizontal.fill } else { Ph.fadersHorizontal.regular }
            }
            .frame(width: 14, height: 14)
            .foregroundStyle(hasActiveFilters ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)
            .frame(width: 36, height: 36)
            .background(hasActiveFilters ? Sourdough.Ramp.sage500 : Sourdough.Colors.sunken)
            .overlay(Circle().stroke(hasActiveFilters ? Color.clear : Sourdough.Colors.interactiveBorder, lineWidth: 1))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - List + pagination

    private var ingredientList: some View {
        List {
            ForEach(Array(filteredIngredients.prefix(visibleCount))) { item in
                row(item)
            }

            if filteredIngredients.count > visibleCount {
                HStack {
                    Spacer()
                    ProgressView().padding(.vertical, Sourdough.Spacing.screenMargin)
                    Spacer()
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .onAppear { visibleCount += Self.pageSize }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(Sourdough.Spacing.insideChip)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 120)
        }
    }

    @ViewBuilder
    private func row(_ item: Ingredient) -> some View {
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

    private var skeletonList: some View {
        VStack(spacing: Sourdough.Spacing.insideChip) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Sourdough.Radius.row, style: .continuous)
                    .fill(Sourdough.Colors.sunken)
                    .frame(height: 72)
            }
        }
        .redacted(reason: .placeholder)
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("No items found")
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.title2)
            Text("Try a different filter or search.")
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.subhead)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Sourdough.Spacing.screenMargin)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous)
                .stroke(Sourdough.Colors.interactiveBorder, style: StrokeStyle(lineWidth: 1, dash: [6]))
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.hero, style: .continuous))
        .padding(Sourdough.Spacing.screenMargin)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

enum SortOption: CaseIterable, Identifiable {
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

enum PantryCategory: String, CaseIterable, Identifiable {
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

// MARK: - Category Filter Sheet (location filtering is handled by the pill row above)

private struct PantryCategoryFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategories: Set<PantryCategory>
    let pantryStore: PantryStore
    let baseIngredients: [Ingredient]

    private var hasActiveFilters: Bool { !selectedCategories.isEmpty }

    private var previewResultCount: Int {
        baseIngredients.filter { ingredient in
            selectedCategories.isEmpty || selectedCategories.contains { $0.matches(ingredient: ingredient) }
        }.count
    }

    private func categoryCount(_ category: PantryCategory) -> Int {
        baseIngredients.filter { category.matches(ingredient: $0) }.count
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
                    HStack {
                        Text("Filters")
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.title1)
                        Spacer()
                        if hasActiveFilters {
                            Button {
                                selectedCategories.removeAll()
                            } label: {
                                Text("Clear")
                                    .foregroundStyle(Sourdough.Colors.actionInk)
                                    .sourdoughTextStyle(.caption)
                                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                                    .padding(.vertical, Sourdough.Spacing.insideChip)
                                    .overlay(Capsule().stroke(Sourdough.Colors.actionInk, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                        Text("CATEGORY")
                            .foregroundStyle(Sourdough.Colors.faintInk)
                            .sourdoughTextStyle(.sectionHead)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals),
                                GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals)
                            ],
                            spacing: Sourdough.Spacing.rowInternals
                        ) {
                            ForEach(PantryCategory.allCases) { category in
                                categoryCard(category)
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

    private func categoryCard(_ category: PantryCategory) -> some View {
        let isSelected = selectedCategories.contains(category)
        return Button {
            toggleSet(&selectedCategories, category)
        } label: {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                category.icon
                    .frame(width: 18, height: 18)
                    .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)

                VStack(alignment: .leading, spacing: 1) {
                    Text(category.label)
                        .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.ink)
                        .sourdoughTextStyle(.rowTitle)
                    let count = categoryCount(category)
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

#Preview("Pantry") {
    PreviewContainer {
        NavigationStack {
            PantryView()
        }
    }
}
