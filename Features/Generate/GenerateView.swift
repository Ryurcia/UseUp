import SwiftUI

struct GenerateView: View {
    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    let recipeGenerator: RecipeGenerating
    var onAddToPantry: (() -> Void)?

    @State private var selectedIngredientIDs: Set<UUID> = []
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var selectedStorageFilters: Set<GenStorageFilter> = []
    @State private var selectedCategories: Set<GenCategory> = []
    @State private var showingFilterSheet = false
    @State private var options = GenerationOptions()
    @State private var recipes: [Recipe] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var step: GenerateStep = .selectIngredients

    private var hasActiveFilters: Bool {
        !selectedStorageFilters.isEmpty || !selectedCategories.isEmpty
    }

    private var filteredIngredients: [Ingredient] {
        pantryStore.ingredients
            .filter { ingredient in
                let trimmed = debouncedSearch.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchesSearch = trimmed.isEmpty || ingredient.name.localizedCaseInsensitiveContains(trimmed)
                let matchesCategory = selectedCategories.isEmpty || selectedCategories.contains { $0.matches(ingredient: ingredient) }
                let matchesStorage = selectedStorageFilters.isEmpty || selectedStorageFilters.contains { $0.matches(ingredient: ingredient) }
                return matchesSearch && matchesCategory && matchesStorage
            }
            .sorted { lhs, rhs in
                switch (lhs.expirationDate, rhs.expirationDate) {
                case let (l?, r?): return l < r
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return false
                }
            }
    }

    private static let expirationDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .selectIngredients:
                ingredientSelectionView
            case .options:
                optionsView
            case .loading:
                generatingView
            case .results:
                resultsView
            }
        }
        .background(DS.ColorToken.bgPrimary)
        .navigationTitle(step.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if step == .selectIngredients {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            GenFilterSheet(
                selectedStorageFilters: $selectedStorageFilters,
                selectedCategories: $selectedCategories
            )
            .presentationDetents([.large])
        }
        .onAppear {
            options.dietType = session.currentUserDietaryPreference
            options.dietaryRestrictions = session.currentUserDietaryRestrictions
        }
        .onChange(of: searchText) { _, newValue in
            searchDebounceTask?.cancel()
            searchDebounceTask = Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                debouncedSearch = newValue
            }
        }
    }

    // MARK: - Step 1: Ingredient Selection

    private var ingredientSelectionView: some View {
        VStack(spacing: 0) {
            VStack(spacing: DS.Spacing.space3) {
                Text("Select the ingredients you'd like to use")
                    .font(.custom("Satoshi Variable", size: 15))
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Search bar
                HStack(spacing: DS.Spacing.space2) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(DS.ColorToken.textTertiary)

                    TextField("Search ingredients", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .appTextStyle(.body)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                }
                .padding(.horizontal, DS.Spacing.space3)
                .frame(height: 44)
                .background(DS.ColorToken.bgSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                        .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))

                // Selection count + filter
                HStack {
                    Text("\(selectedIngredientIDs.count) selected")
                        .font(.custom("Satoshi Variable", size: 14))
                        .foregroundStyle(DS.ColorToken.textSecondary)

                    if !selectedIngredientIDs.isEmpty {
                        Button("Clear") {
                            selectedIngredientIDs.removeAll()
                        }
                        .font(.custom("Satoshi Variable", size: 13))
                        .foregroundStyle(DS.ColorToken.primary)
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button { showingFilterSheet = true } label: {
                        Image(systemName: hasActiveFilters
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                hasActiveFilters
                                    ? DS.ColorToken.primary
                                    : DS.ColorToken.textSecondary
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space3)

            // Ingredient list
            if pantryStore.ingredients.isEmpty {
                Spacer()
                Text("Your pantry is empty.\nAdd ingredients from the Pantry tab first.")
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    if let onAddToPantry {
                        onAddToPantry()
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: DS.Spacing.space1) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add to Pantry")
                            .font(.custom("Satoshi Variable", size: 15).weight(.semibold))
                    }
                    .foregroundStyle(DS.ColorToken.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, DS.Spacing.space3)

                Spacer()
            } else if filteredIngredients.isEmpty {
                Spacer()
                Text("No ingredients match your filters.")
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: DS.Spacing.space2) {
                        ForEach(filteredIngredients) { item in
                            ingredientSelectRow(item)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.space5)
                    .padding(.bottom, DS.Spacing.space16)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [DS.ColorToken.bgPrimary, DS.ColorToken.bgPrimary.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 48)
                    .allowsHitTesting(false)
                }
            }

            // Continue button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    step = .options
                }
            } label: {
                Text("Continue with \(selectedIngredientIDs.count) ingredient\(selectedIngredientIDs.count == 1 ? "" : "s")")
                    .font(.custom("Satoshi Variable", size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(DS.ColorToken.primary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(selectedIngredientIDs.isEmpty)
            .opacity(selectedIngredientIDs.isEmpty ? 0.5 : 1)
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.bottom, DS.Spacing.space4)
        }
    }

    private func ingredientSelectRow(_ item: Ingredient) -> some View {
        let isSelected = selectedIngredientIDs.contains(item.id)

        return Button {
            if isSelected {
                selectedIngredientIDs.remove(item.id)
            } else {
                selectedIngredientIDs.insert(item.id)
            }
        } label: {
            HStack(spacing: DS.Spacing.space3) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? DS.ColorToken.accent : DS.ColorToken.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name.capitalized)
                        .appTextStyle(.body)
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    HStack(spacing: DS.Spacing.space2) {
                        Text(item.location.title)
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        if let amount = item.amount, !amount.isEmpty {
                            Text("·")
                                .foregroundStyle(DS.ColorToken.textTertiary)
                            Text(amount)
                                .appTextStyle(.caption)
                                .foregroundStyle(DS.ColorToken.textSecondary)
                        }

                        if let days = item.daysUntilExpiration, days <= 3 {
                            Text("·")
                                .foregroundStyle(DS.ColorToken.textTertiary)
                            Text(days < 0 ? "Expired" : days == 0 ? "Expires today" : "Expires in \(days)d")
                                .appTextStyle(.caption)
                                .foregroundStyle(days <= 1 ? DS.ColorToken.error : DS.ColorToken.warning)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.space3)
            .padding(.vertical, DS.Spacing.space3)
            .background(
                isSelected
                    ? DS.ColorToken.accentLight
                    : DS.ColorToken.bgSecondary
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(
                        isSelected
                            ? DS.ColorToken.accent.opacity(0.3)
                            : DS.ColorToken.borderDefault,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Options

    private var optionsView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.space6) {
                    // Selected ingredients summary
                    VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                        Text("Selected Ingredients")
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        let selected = pantryStore.ingredients.filter { selectedIngredientIDs.contains($0.id) }
                        FlowLayout(spacing: DS.Spacing.space2) {
                            ForEach(selected) { item in
                                Text(item.name.capitalized)
                                    .font(.custom("Satoshi Variable", size: 13))
                                    .foregroundStyle(DS.ColorToken.accent)
                                    .padding(.horizontal, DS.Spacing.space3)
                                    .padding(.vertical, DS.Spacing.space1)
                                    .background(DS.ColorToken.accentLight)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(DS.ColorToken.accent.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    }

                    // Diet type
                    VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                        HStack(spacing: DS.Spacing.space2) {
                            Text("Diet Type")
                                .appTextStyle(.caption)
                                .foregroundStyle(DS.ColorToken.textSecondary)

                            if session.currentUserDietaryPreference != .any {
                                Text("Using your preferred diet")
                                    .font(.custom("Satoshi Variable", size: 12))
                                    .foregroundStyle(DS.ColorToken.textTertiary)
                            }
                        }

                        FlowLayout(spacing: DS.Spacing.space2) {
                            ForEach(GenerationOptions.DietType.allCases) { dietType in
                                Button {
                                    options.dietType = dietType
                                } label: {
                                    Text(dietType.rawValue)
                                        .font(.custom("Satoshi Variable", size: 14))
                                        .foregroundStyle(
                                            options.dietType == dietType ? .white : DS.ColorToken.textSecondary
                                        )
                                        .padding(.horizontal, DS.Spacing.space3)
                                        .padding(.vertical, DS.Spacing.space2)
                                        .background(
                                            options.dietType == dietType
                                                ? DS.ColorToken.primary
                                                : DS.ColorToken.bgSecondary
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    options.dietType == dietType
                                                        ? Color.clear
                                                        : DS.ColorToken.borderDefault,
                                                    lineWidth: 1
                                                )
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Dietary restrictions
                    VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                        HStack(spacing: DS.Spacing.space2) {
                            Text("Dietary Restrictions")
                                .appTextStyle(.caption)
                                .foregroundStyle(DS.ColorToken.textSecondary)

                            if !session.currentUserDietaryRestrictions.isEmpty {
                                Text("From your profile")
                                    .font(.custom("Satoshi Variable", size: 12))
                                    .foregroundStyle(DS.ColorToken.textTertiary)
                            }
                        }

                        FlowLayout(spacing: DS.Spacing.space2) {
                            ForEach(GenerationOptions.DietaryRestriction.allCases) { restriction in
                                let isSelected = options.dietaryRestrictions.contains(restriction)
                                Button {
                                    if isSelected {
                                        options.dietaryRestrictions.remove(restriction)
                                    } else {
                                        options.dietaryRestrictions.insert(restriction)
                                    }
                                } label: {
                                    Text(restriction.rawValue)
                                        .font(.custom("Satoshi Variable", size: 14))
                                        .foregroundStyle(
                                            isSelected ? .white : DS.ColorToken.textSecondary
                                        )
                                        .padding(.horizontal, DS.Spacing.space3)
                                        .padding(.vertical, DS.Spacing.space2)
                                        .background(
                                            isSelected
                                                ? DS.ColorToken.primary
                                                : DS.ColorToken.bgSecondary
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    isSelected
                                                        ? Color.clear
                                                        : DS.ColorToken.borderDefault,
                                                    lineWidth: 1
                                                )
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Max time
                    VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                        HStack {
                            Text("Max Cooking Time")
                                .appTextStyle(.caption)
                                .foregroundStyle(DS.ColorToken.textSecondary)
                            Spacer()
                            Text("\(options.maxTimeMinutes) min")
                                .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                                .foregroundStyle(DS.ColorToken.textPrimary)
                        }

                        Slider(
                            value: Binding(
                                get: { Double(options.maxTimeMinutes) },
                                set: { options.maxTimeMinutes = Int(($0 / 5).rounded()) * 5 }
                            ),
                            in: 10...60,
                            step: 5
                        )
                        .tint(DS.ColorToken.primary)
                    }

                    // Cuisine
                    VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                        Text("Cuisine (optional)")
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        FlowLayout(spacing: DS.Spacing.space2) {
                            ForEach(Cuisine.allCases.filter { $0 != .other }) { cuisine in
                                Button {
                                    if options.cuisine == cuisine {
                                        options.cuisine = nil
                                    } else {
                                        options.cuisine = cuisine
                                    }
                                } label: {
                                    Text(cuisine.rawValue)
                                        .font(.custom("Satoshi Variable", size: 14))
                                        .foregroundStyle(
                                            options.cuisine == cuisine
                                                ? .white
                                                : DS.ColorToken.textSecondary
                                        )
                                        .padding(.horizontal, DS.Spacing.space3)
                                        .padding(.vertical, DS.Spacing.space2)
                                        .background(
                                            options.cuisine == cuisine
                                                ? DS.ColorToken.primary
                                                : DS.ColorToken.bgSecondary
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(
                                                    options.cuisine == cuisine
                                                        ? Color.clear
                                                        : DS.ColorToken.borderDefault,
                                                    lineWidth: 1
                                                )
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.space5)
                .padding(.top, DS.Spacing.space3)
            }

            VStack(spacing: DS.Spacing.space2) {
                Button {
                    Task { await runGeneration() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Generate Recipes")
                        }
                    }
                    .font(.custom("Satoshi Variable", size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(DS.ColorToken.primary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        step = .selectIngredients
                    }
                } label: {
                    Text("Back to ingredients")
                        .font(.custom("Satoshi Variable", size: 14))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space4)
        }
    }

    // MARK: - Step 3: Results

    private var resultsView: some View {
        VStack(spacing: 0) {
            if let errorText {
                Text(errorText)
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.error)
                    .padding(.horizontal, DS.Spacing.space5)
                    .padding(.top, DS.Spacing.space3)
            }

            if recipes.isEmpty {
                Spacer()
                Text("No recipes generated.")
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: DS.Spacing.space2) {
                        ForEach(recipes) { recipe in
                            NavigationLink {
                                RecipeDetailView(recipe: recipe)
                            } label: {
                                recipeCard(recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.space5)
                    .padding(.top, DS.Spacing.space3)
                    .padding(.bottom, DS.Spacing.space12)
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [DS.ColorToken.bgPrimary, DS.ColorToken.bgPrimary.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 48)
                    .allowsHitTesting(false)
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    step = .selectIngredients
                    recipes = []
                    errorText = nil
                }
            } label: {
                Text("Start Over")
                    .font(.custom("Satoshi Variable", size: 16))
                    .foregroundStyle(DS.ColorToken.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(DS.ColorToken.primaryLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                            .stroke(DS.ColorToken.primary.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space4)
        }
    }

    private func recipeCard(_ recipe: Recipe) -> some View {
        VStack(spacing: 0) {
            // Gradient header
            Color.clear
                .aspectRatio(16/9, contentMode: .fit)
                .background(
                    LinearGradient(
                        colors: [DS.ColorToken.primary, DS.ColorToken.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    AIGeneratedBadge()
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                HStack {
                    Text(recipe.title)
                        .appTextStyle(.heading3)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        savedRecipesStore.toggleSaved(recipe)
                    } label: {
                        Image(systemName: savedRecipesStore.isSaved(recipe) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                savedRecipesStore.isSaved(recipe)
                                    ? DS.ColorToken.primary
                                    : DS.ColorToken.textTertiary
                            )
                    }
                    .buttonStyle(.plain)
                }

                Text(recipe.summary)
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .lineLimit(2)

                HStack(spacing: DS.Spacing.space3) {
                    Label("\(recipe.timeMinutes) min", systemImage: "clock")
                    Label("\(recipe.macros.calories) cal", systemImage: "flame")
                    Label("\(recipe.macros.proteinG)g protein", systemImage: "bolt.heart")
                }
                .appTextStyle(.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
            }
            .padding(.horizontal, DS.Spacing.space3)
            .padding(.vertical, DS.Spacing.space3)
        }
        .background(DS.ColorToken.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Loading

    private var generatingView: some View {
        VStack(spacing: DS.Spacing.space4) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .tint(DS.ColorToken.primary)

            Text("Generating recipes...")
                .font(.custom("CalSans-Regular", size: 20))
                .kerning(0)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Text("Finding the best dishes from your ingredients")
                .font(.custom("Satoshi Variable", size: 15))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.space5)
    }

    // MARK: - Generation

    @MainActor
    private func runGeneration() async {
        errorText = nil

        withAnimation(.easeInOut(duration: 0.25)) {
            step = .loading
        }

        let names = pantryStore.ingredients
            .filter { selectedIngredientIDs.contains($0.id) }
            .map(\.name)

        do {
            recipes = try await recipeGenerator.generateRecipes(
                for: names,
                options: options
            )
            withAnimation(.easeInOut(duration: 0.25)) {
                step = .results
            }
        } catch {
            recipes = []
            errorText = error.localizedDescription
            withAnimation(.easeInOut(duration: 0.25)) {
                step = .results
            }
        }
    }
}

// MARK: - Generate Step

private enum GenerateStep {
    case selectIngredients
    case options
    case loading
    case results

    var title: String {
        switch self {
        case .selectIngredients: return "Select Ingredients"
        case .options: return "Recipe Options"
        case .loading: return "Generating"
        case .results: return "Generated Recipes"
        }
    }
}

// MARK: - Filter Enums

private enum GenStorageFilter: CaseIterable, Identifiable {
    case fridge, freezer, pantry

    var id: String { label }

    var label: String {
        switch self {
        case .fridge: return "Fridge"
        case .freezer: return "Freezer"
        case .pantry: return "Pantry"
        }
    }

    var icon: String {
        switch self {
        case .fridge: return "refrigerator"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet"
        }
    }

    func matches(ingredient: Ingredient) -> Bool {
        switch self {
        case .fridge: return ingredient.location == .fridge
        case .freezer: return ingredient.location == .freezer
        case .pantry: return ingredient.location == .pantry
        }
    }
}

private enum GenCategory: String, CaseIterable, Identifiable {
    case proteins, vegetables, carbs, dairy, fruits, condiments, other

    var id: String { rawValue }

    var label: String { ingredientCategory.title }
    var icon: String { ingredientCategory.icon }

    var ingredientCategory: Ingredient.Category {
        switch self {
        case .proteins: return .proteins
        case .vegetables: return .vegetables
        case .carbs: return .carbs
        case .dairy: return .dairy
        case .fruits: return .fruits
        case .condiments: return .condiments
        case .other: return .other
        }
    }

    func matches(ingredient: Ingredient) -> Bool {
        ingredient.category == ingredientCategory
    }
}

// MARK: - Filter Sheet

private struct GenFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStorageFilters: Set<GenStorageFilter>
    @Binding var selectedCategories: Set<GenCategory>

    private var hasActiveFilters: Bool {
        !selectedStorageFilters.isEmpty || !selectedCategories.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DS.ColorToken.borderDefault)
                .frame(width: 36, height: 5)
                .padding(.top, DS.Spacing.space3)
                .padding(.bottom, DS.Spacing.space4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.space6) {
                    HStack {
                        Text("Filters")
                            .appTextStyle(.heading2)
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        Spacer()

                        if hasActiveFilters {
                            Button {
                                selectedStorageFilters.removeAll()
                                selectedCategories.removeAll()
                            } label: {
                                Text("Reset")
                                    .font(.custom("Satoshi Variable", size: 14))
                                    .foregroundStyle(DS.ColorToken.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                        Text("Storage")
                            .appTextStyle(.heading3)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        VStack(spacing: DS.Spacing.space2) {
                            ForEach(GenStorageFilter.allCases) { filter in
                                filterRow(
                                    icon: filter.icon,
                                    label: filter.label,
                                    isSelected: selectedStorageFilters.contains(filter)
                                ) {
                                    toggleSet(&selectedStorageFilters, filter)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                        Text("Category")
                            .appTextStyle(.heading3)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        VStack(spacing: DS.Spacing.space2) {
                            ForEach(GenCategory.allCases) { category in
                                filterRow(
                                    icon: category.icon,
                                    label: category.label,
                                    isSelected: selectedCategories.contains(category)
                                ) {
                                    toggleSet(&selectedCategories, category)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.space5)
            }

            Button { dismiss() } label: {
                Text("Apply Filters")
                    .font(.custom("Satoshi Variable", size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(DS.ColorToken.primary)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space4)
        }
    }

    private func toggleSet<T: Hashable>(_ set: inout Set<T>, _ item: T) {
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
    }

    private func filterRow(
        icon: String,
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.space3) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        isSelected
                            ? DS.ColorToken.accent
                            : DS.ColorToken.textTertiary
                    )

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        isSelected
                            ? DS.ColorToken.accent
                            : DS.ColorToken.textSecondary
                    )
                    .frame(width: 24)

                Text(label)
                    .font(.custom("Satoshi Variable", size: 16))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.space5)
            .frame(height: 48)
            .background(
                isSelected
                    ? DS.ColorToken.accentLight
                    : DS.ColorToken.bgSecondary
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(
                        isSelected
                            ? DS.ColorToken.accent.opacity(0.3)
                            : DS.ColorToken.borderDefault,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Generate") {
    PreviewContainer {
        NavigationStack {
            GenerateView(recipeGenerator: previewRecipeGenerator)
        }
    }
}
