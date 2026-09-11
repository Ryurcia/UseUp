import SwiftUI
import PhosphorSwift

struct CookbookView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @State private var showAddRecipeOptions = false
    @State private var showPasteURLSheet = false
    @State private var cookbookRecipeData: RecipeImportData? = nil
    @State private var pendingSheetWork: DispatchWorkItem? = nil
    @State private var primaryTab: CookbookPrimaryTab = .recipes
    @State private var recipesFilter: RecipesFilter = .all
    @AppStorage("cookbookLayoutMode") private var cookbookLayoutMode: CookbookLayoutMode = .list
    @State private var searchText = ""
    @State private var navigateToRecipe: Recipe?
    @State private var navigateToCollection: RecipeCollection?
    @State private var collectionPendingDelete: RecipeCollection?
    @State private var allergenPendingRecipe: Recipe?
    @State private var allergenWarningDetected: [String] = []
    @State private var recipePendingDelete: Recipe?
    @State private var recipePendingCollectionPick: Recipe?

    private enum CookbookPrimaryTab: CaseIterable {
        case recipes, collections
        var label: String {
            switch self {
            case .recipes:     return "Recipes"
            case .collections: return "Collections"
            }
        }
    }

    private enum RecipesFilter: CaseIterable {
        case all, saved, sharedByYou
        var label: String {
            switch self {
            case .all:         return "All"
            case .saved:       return "Saved"
            case .sharedByYou: return "Shared by you"
            }
        }
    }

    private enum CookbookLayoutMode: String {
        case list, grid
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "Saved" = bookmarked, not authored by the current user. "Shared by you" = authored by the
    /// current user *and* published (`isUserShared` excludes private/unshared cookbook recipes
    /// from this pill). "All" = `savedRecipes`, unfiltered. `isUserShared` is a recipe-level
    /// "published to the community" flag set by the author at creation time — it does NOT mean
    /// "shared by the current viewer", so it must be combined with `createdBy` to identify
    /// authorship (same pattern as `RecipeDetailView.swift`'s `isOwner` check).
    private var baseRecipes: [Recipe] {
        switch recipesFilter {
        case .all:         return savedRecipesStore.savedRecipes
        case .saved:       return savedRecipesStore.savedRecipes.filter { $0.createdBy != savedRecipesStore.userId?.uuidString }
        case .sharedByYou: return savedRecipesStore.savedRecipes.filter { $0.isUserShared && $0.createdBy == savedRecipesStore.userId?.uuidString }
        }
    }

    private var filteredRecipes: [Recipe] {
        let recipes = baseRecipes
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
                        Ph.plus.bold
                            .frame(width: 16, height: 16)
                        Text("Add")
                            .foregroundStyle(Sourdough.Colors.onAction)
                            .sourdoughTextStyle(.numeric)
                    }
                    .foregroundStyle(Sourdough.Colors.onAction)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .frame(height: 40)
                    .background(Sourdough.Colors.action)
                    .clipShape(Capsule())
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
        .navigationDestination(item: $navigateToCollection) { collection in
            CollectionDetailView(collection: collection)
        }
        .alert("Delete collection?", isPresented: isShowingDeleteCollectionAlert, presenting: collectionPendingDelete) { collection in
            Button("Cancel", role: .cancel) { collectionPendingDelete = nil }
            Button("Delete", role: .destructive) {
                savedRecipesStore.deleteCollection(collection)
                collectionPendingDelete = nil
            }
        } message: { collection in
            Text("This will delete \"\(collection.name)\". Recipes inside it will stay in your cookbook.")
        }
        .alert("Delete Recipe?", isPresented: Binding(
            get: { recipePendingDelete != nil },
            set: { if !$0 { recipePendingDelete = nil } }
        ), presenting: recipePendingDelete) { recipe in
            Button("Delete", role: .destructive) {
                savedRecipesStore.deleteRecipe(recipe)
                recipePendingDelete = nil
            }
            Button("Cancel", role: .cancel) { recipePendingDelete = nil }
        } message: { recipe in
            Text("\"\(recipe.title)\" will be permanently deleted and cannot be recovered.")
        }
        .sheet(item: $allergenPendingRecipe) { recipe in
            AllergenWarningSheet(recipeName: recipe.title) {
                navigateToRecipe = recipe
            }
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
        .sheet(item: $recipePendingCollectionPick) { recipe in
            CollectionPickerSheet(recipe: recipe, excludeExisting: true) {
                recipePendingCollectionPick = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Sourdough.Spacing.insideChip) {
            Ph.magnifyingGlass.regular
                .frame(width: 18, height: 18)
                .foregroundStyle(Sourdough.Colors.faintInk)
            TextField(primaryTab == .collections ? "Search collections" : "Search recipes", text: $searchText)
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
        .padding(.top, Sourdough.Spacing.iconToLabel)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
    }

    // MARK: - Tab Bar

    private var primaryTabBar: some View {
        HStack(spacing: Sourdough.Spacing.iconToLabel) {
            ForEach(CookbookPrimaryTab.allCases, id: \.label) { tab in
                Button {
                    // Both tabs share one search field; carrying a recipe query across would
                    // silently filter the collections grid (and vice versa).
                    searchText = ""
                    withAnimation(.easeInOut(duration: 0.2)) { primaryTab = tab }
                } label: {
                    Text(tab.label)
                        .foregroundStyle(primaryTab == tab ? Sourdough.Colors.ink : Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.rowTitle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(primaryTab == tab ? Sourdough.Colors.card : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))
                        .shadow(color: primaryTab == tab ? .black.opacity(0.08) : .clear, radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Sourdough.Colors.sunken)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous))
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
    }

    private var recipesFilterRow: some View {
        HStack(spacing: Sourdough.Spacing.iconToLabel) {
            ForEach(RecipesFilter.allCases, id: \.label) { filter in
                SelectableChip(label: filter.label, isSelected: recipesFilter == filter, size: .medium) {
                    withAnimation(.easeInOut(duration: 0.2)) { recipesFilter = filter }
                }
            }
            Spacer()
            layoutToggle
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
    }

    private var layoutToggle: some View {
        HStack(spacing: 2) {
            layoutToggleButton(.list, icon: Ph.list.bold)
            layoutToggleButton(.grid, icon: Ph.squaresFour.bold)
        }
        .padding(3)
        .background(Sourdough.Colors.sunken)
        .clipShape(Capsule())
    }

    private func layoutToggleButton(_ mode: CookbookLayoutMode, icon: Image) -> some View {
        let selected = cookbookLayoutMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) { cookbookLayoutMode = mode }
        } label: {
            icon
                .frame(width: 15, height: 15)
                .foregroundStyle(selected ? Sourdough.Colors.ink : Sourdough.Colors.mutedInk)
                .frame(width: 30, height: 30)
                .background(selected ? Sourdough.Colors.card : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Premium Content

    private var premiumContent: some View {
        VStack(spacing: 0) {
            searchBar
            primaryTabBar

            if primaryTab == .collections {
                CollectionsSection(
                    navigateToCollection: $navigateToCollection,
                    collectionPendingDelete: $collectionPendingDelete,
                    searchQuery: searchText
                )
            } else {
                recipesFilterRow

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
    }

    private var isShowingDeleteCollectionAlert: Binding<Bool> {
        Binding(
            get: { collectionPendingDelete != nil },
            set: { newValue in
                if !newValue { collectionPendingDelete = nil }
            }
        )
    }

    // MARK: - Recipe List

    private var emptyStateMessage: String {
        if !searchQuery.isEmpty { return "No results for \"\(searchQuery)\"" }
        switch recipesFilter {
        case .all:         return "Your cookbook is empty"
        case .saved:       return "No saved recipes yet"
        case .sharedByYou: return "No shared recipes yet"
        }
    }

    private var emptyStateSubtitle: String {
        if !searchQuery.isEmpty { return "Try a different search term." }
        switch recipesFilter {
        case .all:         return "Save recipes from the community to build your collection."
        case .saved:       return "Browse the community to find recipes."
        case .sharedByYou: return "Share a recipe with the community."
        }
    }

    private func handleTap(_ recipe: Recipe) {
        allergenWarningDetected = []
        let detected = detectAllergens(
            in: recipe,
            userAllergies: session.currentUserAllergies,
            customAllergy: session.currentUserCustomAllergy
        )
        if detected.isEmpty {
            navigateToRecipe = recipe
        } else {
            allergenWarningDetected = detected
            allergenPendingRecipe = recipe
        }
    }

    private var noResultsState: some View {
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
    }

    @ViewBuilder
    private var recipeList: some View {
        switch cookbookLayoutMode {
        case .list: recipeRows
        case .grid: recipeGrid
        }
    }

    private var recipeRows: some View {
        List {
            if filteredRecipes.isEmpty {
                noResultsState
                    .padding(.top, Sourdough.Spacing.aboveSectionHead)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredRecipes) { recipe in
                    CookbookListRow(
                        recipe: recipe,
                        onTap: { handleTap($0) },
                        onAddToCollection: { recipePendingCollectionPick = recipe },
                        onUnsave: recipe.createdBy != savedRecipesStore.userId?.uuidString ? {
                            savedRecipesStore.unsaveRecipe(recipe)
                        } : nil,
                        onDelete: (recipe.createdBy == savedRecipesStore.userId?.uuidString && !recipe.isUserShared) ? {
                            recipePendingDelete = recipe
                        } : nil
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: Sourdough.Spacing.screenMargin, bottom: 0, trailing: Sourdough.Spacing.screenMargin))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Color.clear
                    .frame(height: 96)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .listRowSpacing(Sourdough.Spacing.insideChip)
        .scrollIndicators(.hidden)
        .scrollContentBackground(.hidden)
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals),
        GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals),
    ]

    private var recipeGrid: some View {
        ScrollView(showsIndicators: false) {
            if filteredRecipes.isEmpty {
                noResultsState
                    .padding(.top, Sourdough.Spacing.aboveSectionHead)
            } else {
                LazyVGrid(columns: gridColumns, spacing: Sourdough.Spacing.betweenBlocks) {
                    ForEach(filteredRecipes) { recipe in
                        CookbookGridTile(
                            recipe: recipe,
                            isSaved: savedRecipesStore.isSaved(recipe),
                            onTap: { handleTap(recipe) },
                            onAddToCollection: { recipePendingCollectionPick = recipe },
                            onUnsave: recipe.createdBy != savedRecipesStore.userId?.uuidString ? {
                                savedRecipesStore.unsaveRecipe(recipe)
                            } : nil,
                            onDelete: (recipe.createdBy == savedRecipesStore.userId?.uuidString && !recipe.isUserShared) ? {
                                recipePendingDelete = recipe
                            } : nil
                        )
                    }
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.insideChip)
                .padding(.bottom, 96)
            }
        }
    }

}

/// Grid-mode counterpart to `CookbookListRow` — same add/unsave/delete contract, rendered as a
/// `RecipeCard` tile instead of a row. No `.swipeActions` (not inside a `List`); long-press
/// context menu covers the same actions.
private struct CookbookGridTile: View {
    let recipe: Recipe
    var isSaved: Bool = false
    let onTap: () -> Void
    var onAddToCollection: (() -> Void)? = nil
    var onUnsave: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        Button(action: onTap) {
            RecipeCard(recipe: recipe, isSaved: isSaved)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onAddToCollection {
                Button { onAddToCollection() } label: {
                    Label {
                        Text("Add to Collection")
                    } icon: {
                        Ph.folders.regular.frame(width: 16, height: 16)
                    }
                }
            }
            if let onUnsave {
                Button(role: .destructive) { onUnsave() } label: {
                    Label {
                        Text("Remove from Saved")
                    } icon: {
                        Ph.bookmark.regular.frame(width: 16, height: 16)
                    }
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label {
                        Text("Delete Recipe")
                    } icon: {
                        Ph.trash.regular.frame(width: 16, height: 16)
                    }
                }
            }
        }
    }
}

// MARK: - Cookbook List Row

struct CookbookListRow: View {
    let recipe: Recipe
    let onTap: (Recipe) -> Void
    var onAddToCollection: (() -> Void)? = nil
    var onUnsave: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onRemoveFromCollection: (() -> Void)? = nil

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
                    if recipe.imageData == nil && recipe.imagePath == nil {
                        RecipeImagePlaceholder()
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
            if let onAddToCollection {
                Button { onAddToCollection() } label: {
                    Label {
                        Text("Add to Collection")
                    } icon: {
                        Ph.folders.regular.frame(width: 16, height: 16)
                    }
                }
            }
            if let onUnsave {
                Button(role: .destructive) { onUnsave() } label: {
                    Label {
                        Text("Remove from Saved")
                    } icon: {
                        Ph.bookmark.regular.frame(width: 16, height: 16)
                    }
                }
            }
            if let onDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Label {
                        Text("Delete Recipe")
                    } icon: {
                        Ph.trash.regular.frame(width: 16, height: 16)
                    }
                }
            }
            if let onRemoveFromCollection {
                Button(role: .destructive) { onRemoveFromCollection() } label: {
                    Label {
                        Text("Remove from Collection")
                    } icon: {
                        Ph.folders.regular.frame(width: 16, height: 16)
                    }
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onUnsave {
                Button(role: .destructive, action: onUnsave) {
                    Label("Unsave", systemImage: "bookmark.slash")
                }
                .tint(Sourdough.Colors.destructive)
            }
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .tint(Sourdough.Colors.destructive)
            }
            if let onRemoveFromCollection {
                Button(role: .destructive, action: onRemoveFromCollection) {
                    Label("Remove", systemImage: "folder.badge.minus")
                }
                .tint(Sourdough.Colors.destructive)
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
