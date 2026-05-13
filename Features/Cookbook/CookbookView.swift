import SwiftUI
import RevenueCatUI

struct CookbookView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @State private var showingSettings = false
    @State private var showPaywall = false
    @State private var showAddRecipeOptions = false
    @State private var showPasteURLSheet = false
    @State private var cookbookRecipeData: RecipeImportData? = nil
    @State private var selectedCategory: CookbookCategory = .all
    @State private var searchText = ""
    var onGenerateTapped: () -> Void = {}

    private enum CookbookCategory: String, CaseIterable {
        case all = "All"
        case breakfast = "Breakfast"
        case lunch = "Lunch"
        case dinner = "Dinner"
        case snack = "Snack"

        var filterValue: String? {
            switch self {
            case .all: return nil
            case .breakfast: return "breakfast"
            case .lunch: return "lunch"
            case .dinner: return "dinner"
            case .snack: return "snack"
            }
        }

        var icon: String {
            switch self {
            case .all: return "book.fill"
            case .breakfast: return "sunrise.fill"
            case .lunch: return "sun.max.fill"
            case .dinner: return "moon.fill"
            case .snack: return "cup.and.saucer.fill"
            }
        }
    }

    private struct CookbookSection: Identifiable {
        var id: String { title }
        let title: String
        let icon: String
        let category: CookbookCategory?
        let recipes: [Recipe]
    }

    private var searchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredSavedRecipes: [Recipe] {
        let query = searchQuery
        guard !query.isEmpty else { return savedRecipesStore.savedRecipes }
        return savedRecipesStore.savedRecipes.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.summary.localizedCaseInsensitiveContains(query)
        }
    }

    private var groupedSections: [CookbookSection] {
        let recipes = filteredSavedRecipes
        if selectedCategory != .all {
            let filtered = recipes.filter {
                savedRecipesStore.savedRecipeCategories[$0.id] == selectedCategory.filterValue
            }
            return filtered.isEmpty ? [] : [CookbookSection(title: selectedCategory.rawValue, icon: selectedCategory.icon, category: selectedCategory, recipes: filtered)]
        }

        let orderedCategories: [CookbookCategory] = [.breakfast, .lunch, .dinner, .snack]
        var sections: [CookbookSection] = []
        for cat in orderedCategories {
            let catRecipes = recipes.filter {
                savedRecipesStore.savedRecipeCategories[$0.id] == cat.filterValue
            }
            if !catRecipes.isEmpty {
                sections.append(CookbookSection(title: cat.rawValue, icon: cat.icon, category: cat, recipes: catRecipes))
            }
        }
        let otherRecipes = recipes.filter {
            savedRecipesStore.savedRecipeCategories[$0.id] == nil
        }
        if !otherRecipes.isEmpty {
            sections.append(CookbookSection(title: "Other", icon: "ellipsis.circle", category: nil, recipes: otherRecipes))
        }
        return sections
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.space4) {
                Text("Cookbook")
                    .font(.custom("CalSans-Regular", size: 28))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                Spacer()
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
                .buttonStyle(.plain)
                NotificationBellButton()
                ProfileNavButton()
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space2)

            if session.isPremium {
                premiumContent
            } else {
                lockedContent
            }
        }
        .background(DS.ColorToken.bgPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailView(recipe: recipe)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .onPurchaseCompleted { _ in showPaywall = false }
                .onRestoreCompleted { _ in showPaywall = false }
        }
        .sheet(isPresented: $showAddRecipeOptions) {
            AddRecipeOptionsSheet(
                onAddManually: {
                    showAddRecipeOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        cookbookRecipeData = RecipeImportData()
                    }
                },
                onPasteURL: {
                    showAddRecipeOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        showPasteURLSheet = true
                    }
                }
            )
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPasteURLSheet) {
            PasteURLSheet { importData in
                showPasteURLSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    cookbookRecipeData = importData
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $cookbookRecipeData) { data in
            ShareRecipeSheet(sheetTitle: "Add Recipe", prefill: data, isCookbookRecipe: true)
        }
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.space2) {
                ForEach(CookbookCategory.allCases, id: \.self) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12))
                            Text(category.rawValue)
                                .font(.custom("Satoshi Variable", size: 13).weight(.medium))
                        }
                        .foregroundStyle(selectedCategory == category ? .white : DS.ColorToken.textSecondary)
                        .padding(.horizontal, DS.Spacing.space3)
                        .frame(height: 36)
                        .background(selectedCategory == category ? DS.ColorToken.accent : DS.ColorToken.bgSecondary)
                        .overlay(
                            Capsule().stroke(
                                selectedCategory == category ? Color.clear : DS.ColorToken.borderDefault,
                                lineWidth: 1
                            )
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.space5)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.8),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .padding(.vertical, DS.Spacing.space2)
    }

    // MARK: - Premium Content

    private var premiumContent: some View {
        VStack(spacing: 0) {
            categoryTabs

            HStack(spacing: DS.Spacing.space2) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DS.ColorToken.textTertiary)
                TextField("Search recipes", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .appTextStyle(.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DS.ColorToken.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.space3)
            .frame(height: 48)
            .background(DS.ColorToken.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                    .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space1)
            .padding(.bottom, DS.Spacing.space3)

            if savedRecipesStore.savedRecipes.isEmpty && searchQuery.isEmpty {
                Spacer()
                VStack(spacing: DS.Spacing.space3) {
                    // Action cards even when empty
                    actionCards
                        .padding(.horizontal, DS.Spacing.space5)
                        .padding(.bottom, DS.Spacing.space6)

                    Image(systemName: "book.closed")
                        .font(.system(size: 48))
                        .foregroundStyle(DS.ColorToken.textTertiary)
                    Text("Your cookbook is empty")
                        .font(.custom("Satoshi Variable", size: 18).weight(.semibold))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                    Text("Save recipes from the community to build your collection.")
                        .appTextStyle(.bodySM)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DS.Spacing.space8)
                Spacer()
            } else {
                recipeList
            }
        }
    }

    // MARK: - Action Cards

    private var actionCards: some View {
        HStack(spacing: DS.Spacing.space3) {
            Button(action: onGenerateTapped) {
                VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Generate from pantry")
                        .font(.custom("Satoshi Variable", size: 16).weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text("AI suggestions")
                        .font(.custom("Satoshi Variable", size: 13))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(DS.Spacing.space4)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                .background(DS.ColorToken.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .stroke(DS.ColorToken.accent, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)

            Button { showAddRecipeOptions = true } label: {
                VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                    Spacer()
                    Text("Add recipe")
                        .font(.custom("Satoshi Variable", size: 16).weight(.bold))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                    Text("Paste URL or photo")
                        .font(.custom("Satoshi Variable", size: 13))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
                .padding(DS.Spacing.space4)
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
                .background(DS.ColorToken.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Recipe List

    private var recipeList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                actionCards
                    .padding(.horizontal, DS.Spacing.space5)
                    .padding(.bottom, DS.Spacing.space4)

                if groupedSections.isEmpty {
                    VStack(spacing: DS.Spacing.space3) {
                        Image(systemName: searchQuery.isEmpty ? selectedCategory.icon : "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(DS.ColorToken.textTertiary)
                        Text(!searchQuery.isEmpty ? "No results for \"\(searchQuery)\"" : "No \(selectedCategory.rawValue.lowercased()) recipes yet")
                            .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                            .foregroundStyle(DS.ColorToken.textPrimary)
                        Text(!searchQuery.isEmpty ? "Try a different search term." : "Save recipes from the community to build your collection.")
                            .appTextStyle(.bodySM)
                            .foregroundStyle(DS.ColorToken.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DS.Spacing.space8)
                    .padding(.top, DS.Spacing.space8)
                } else {
                    ForEach(groupedSections) { section in
                        if selectedCategory == .all {
                            sectionHeader(section)
                        }
                        let preview = selectedCategory == .all ? Array(section.recipes.prefix(3)) : section.recipes
                        ForEach(Array(preview.enumerated()), id: \.element.id) { index, recipe in
                            CookbookListRow(
                                recipe: recipe,
                                category: savedRecipesStore.savedRecipeCategories[recipe.id]
                            )
                            if index < preview.count - 1 {
                                Divider()
                                    .padding(.leading, DS.Spacing.space5 + 60 + DS.Spacing.space3)
                            }
                        }
                        Divider()
                            .padding(.horizontal, DS.Spacing.space5)
                            .padding(.bottom, DS.Spacing.space2)
                    }
                }
            }
            .padding(.bottom, DS.Spacing.space24)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ section: CookbookSection) -> some View {
        HStack(spacing: DS.Spacing.space2) {
            Image(systemName: section.icon)
                .font(.system(size: 14))
                .foregroundStyle(DS.ColorToken.textSecondary)
            Text(section.title)
                .font(.custom("Satoshi Variable", size: 18).weight(.bold))
                .foregroundStyle(DS.ColorToken.textPrimary)
            Text("\(section.recipes.count)")
                .font(.custom("Satoshi Variable", size: 14))
                .foregroundStyle(DS.ColorToken.textTertiary)
            Spacer()
            if section.recipes.count > 3, let cat = section.category {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = cat }
                } label: {
                    Text("See all")
                        .font(.custom("Satoshi Variable", size: 13).weight(.medium))
                        .foregroundStyle(DS.ColorToken.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.top, DS.Spacing.space4)
        .padding(.bottom, DS.Spacing.space2)
    }

    // MARK: - Locked Content

    private var lockedContent: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: DS.Spacing.space4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DS.ColorToken.textTertiary)
                Text("Unlock Your Cookbook")
                    .font(.custom("CalSans-Regular", size: 24))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                Text("Save and organize your favorite recipes.\nUpgrade to Pro to access your personal cookbook.")
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: DS.Spacing.space2) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Upgrade to Pro")
                            .font(.custom("Satoshi Variable", size: 16))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [DS.ColorToken.berry, DS.ColorToken.lavender],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DS.Spacing.space5)
            }
            .padding(.horizontal, DS.Spacing.space5)
            Spacer()
        }
    }
}

// MARK: - Cookbook List Row

private struct CookbookListRow: View {
    let recipe: Recipe
    let category: String?

    var metaLine: String {
        var parts: [String] = ["\(recipe.timeMinutes) min"]
        if recipe.dietType != "any" { parts.append(recipe.dietType.capitalized) }
        parts += recipe.dietaryRestrictions.prefix(2)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationLink(value: recipe) {
            HStack(spacing: DS.Spacing.space3) {
                // Thumbnail
                Group {
                    if recipe.isAIGenerated && recipe.imageData == nil && recipe.imagePath == nil {
                        ZStack {
                            LinearGradient(
                                colors: [DS.ColorToken.primary, DS.ColorToken.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            Image(systemName: "fork.knife")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    } else {
                        CachedRecipeImage(recipeID: recipe.id, imageData: recipe.imageData, imagePath: recipe.imagePath, thumbnail: true)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.custom("Satoshi Variable", size: 15).weight(.semibold))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.ColorToken.textTertiary)
                        Text(metaLine)
                            .font(.custom("Satoshi Variable", size: 12))
                            .foregroundStyle(DS.ColorToken.textSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.ColorToken.textTertiary)
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.vertical, DS.Spacing.space3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Recipe Options Sheet

private struct AddRecipeOptionsSheet: View {
    var onAddManually: () -> Void = {}
    var onPasteURL: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DS.Spacing.space3) {
            Spacer()

            Button {
                onAddManually()
            } label: {
                HStack(spacing: DS.Spacing.space3) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Manually")
                            .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                        Text("Fill in title, ingredients and steps")
                            .font(.custom("Satoshi Variable", size: 12))
                            .foregroundStyle(DS.ColorToken.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }
                .foregroundStyle(DS.ColorToken.textPrimary)
                .padding(DS.Spacing.space4)
                .frame(maxWidth: .infinity)
                .background(DS.ColorToken.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                onPasteURL()
            } label: {
                HStack(spacing: DS.Spacing.space3) {
                    Image(systemName: "link")
                        .font(.system(size: 18, weight: .medium))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Paste a URL")
                            .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                        Text("Import from any recipe website")
                            .font(.custom("Satoshi Variable", size: 12))
                            .foregroundStyle(DS.ColorToken.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }
                .foregroundStyle(DS.ColorToken.textPrimary)
                .padding(DS.Spacing.space4)
                .frame(maxWidth: .infinity)
                .background(DS.ColorToken.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            }
            .buttonStyle(.plain)

        }
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.vertical, DS.Spacing.space4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.ColorToken.bgPrimary)
    }
}
