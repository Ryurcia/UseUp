import SwiftUI
import PhosphorSwift

struct GenerateView: View {
    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var activityStore: UserActivityStore
    let recipeGenerator: RecipeGenerating

    @State private var selectedIngredientIDs: Set<UUID> = []
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var generationTask: Task<Void, Never>?
    @State private var selectedStorageFilters: Set<IngredientStorageFilter> = []
    @State private var selectedCategories: Set<GenCategory> = []
    @State private var cachedFilteredIngredients: [Ingredient] = []
    @State private var showingFilterSheet = false
    @State private var options = GenerationOptions()
    @State private var recipes: [Recipe] = []
    @State private var isLoading = false
    @State private var generationError: Error?
    @State private var step: GenerateStep = .selectIngredients
    @State private var hasNoRestrictions = true
    @State private var selectedAllergies: Set<AllergyType> = []
    @State private var customAllergy: String = ""
    @State private var showAllergyOtherField = false
    @State private var showPaywall = false
    @State private var showSnapChef = false
    @State private var goForward = true
    @State private var caloriesEnabled: Bool = false

    private var isInOptionsFlow: Bool {
        switch step {
        case .selectDiet, .selectRestrictions, .selectAllergies, .selectCookTime, .selectCuisine:
            return true
        default:
            return false
        }
    }

    private var hasActiveFilters: Bool {
        !selectedStorageFilters.isEmpty || !selectedCategories.isEmpty
    }

    private var isLimitExhausted: Bool {
        activityStore.generationsToday >= 5
    }

    // Cached filter result — recomputed via recomputeFilteredIngredients() on relevant changes,
    // not on every body render (filter + O(n log n) sort).
    private func recomputeFilteredIngredients() {
        cachedFilteredIngredients = pantryStore.ingredients
            .filter { ingredient in
                let trimmed = debouncedSearch.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchesSearch = trimmed.isEmpty || ingredient.name.localizedCaseInsensitiveContains(trimmed)
                let matchesCategory = selectedCategories.isEmpty || selectedCategories.contains { $0.matches(ingredient: ingredient) }
                let matchesStorage = selectedStorageFilters.isEmpty || selectedStorageFilters.contains { $0.matches(ingredient: ingredient) }
                return !ingredient.isExpired && matchesSearch && matchesCategory && matchesStorage
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

    private var sortedCuisines: [Cuisine] {
        Cuisine.allCases.filter { $0 != .other }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isInOptionsFlow {
                HStack(spacing: Sourdough.Spacing.screenMargin) {
                    Text("Generate")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.title1)

                    Spacer()

                    NotificationBellButton()
                    ProfileNavButton()
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.iconToLabel)

                generationCountRow
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, Sourdough.Spacing.insideChip)
            }

            Group {
                switch step {
                case .selectIngredients:  ingredientSelectionView
                case .options:            optionsStepView
                case .selectDiet:         dietSelectView
                case .selectRestrictions: restrictionsSelectView
                case .selectAllergies:    allergiesSelectView
                case .selectCookTime:     cookTimeSelectView
                case .selectCuisine:      cuisineSelectView
                case .loading:            generatingView
                case .results:            resultsView
                }
            }
            .id(step)
            .transition(pageTransition)
        }
        .clipped()
        .background(Sourdough.Colors.canvas)
        .preference(key: HideTabBarKey.self, value: isInOptionsFlow)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: isInOptionsFlow ? 0 : 80)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingFilterSheet) {
            GenFilterSheet(
                selectedStorageFilters: $selectedStorageFilters,
                selectedCategories: $selectedCategories
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showPaywall) {
            UseUpPaywallView { showPaywall = false }
        }
        .fullScreenCover(isPresented: $showSnapChef) {
            SnapChefFlow(recipeGenerator: recipeGenerator, onFinished: {
                showSnapChef = false
                Task { await activityStore.fetchGenerationsToday() }
            })
        }
        .task {
            await activityStore.fetchGenerationsToday()
        }
        .onAppear {
            seedOptionsFromProfile()
            recomputeFilteredIngredients()
        }
        .onChange(of: pantryStore.ingredients) { _, _ in
            recomputeFilteredIngredients()
        }
        .onChange(of: debouncedSearch) { _, _ in
            recomputeFilteredIngredients()
        }
        .onChange(of: selectedCategories) { _, _ in
            recomputeFilteredIngredients()
        }
        .onChange(of: selectedStorageFilters) { _, _ in
            recomputeFilteredIngredients()
        }
        .onChange(of: session.requestedIngredientID) { _, id in
            guard let id else { return }
            session.requestedIngredientID = nil
            guard let ingredient = pantryStore.ingredients.first(where: { $0.id == id }), !ingredient.isExpired else { return }
            selectedIngredientIDs = [id]
        }
        .onChange(of: session.requestedQuickGenerateIngredientID) { _, id in
            guard let id else { return }
            session.requestedQuickGenerateIngredientID = nil
            guard let ingredient = pantryStore.ingredients.first(where: { $0.id == id }), !ingredient.isExpired else { return }

            guard !isLimitExhausted else { return }

            // Quick Generation always starts from the baseline defaults — not whatever the user
            // last left `options` at in a manual session — then layers on saved profile prefs,
            // same as a fresh visit to this tab would.
            options = GenerationOptions()
            seedOptionsFromProfile()
            selectedIngredientIDs = [id]

            generationTask?.cancel()
            generationTask = Task { await runGeneration() }
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

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goForward ? .trailing : .leading),
            removal: .move(edge: goForward ? .leading : .trailing)
        )
    }

    private func goToStep(_ newStep: GenerateStep, forward: Bool = true) {
        goForward = forward
        withAnimation(.easeInOut(duration: 0.3)) {
            step = newStep
        }
    }

    /// Applies the user's saved dietary preference/restrictions/skill level/allergies onto
    /// `options` (and the allergy-editing local state that `runGeneration()` folds back in) —
    /// shared by the normal `.onAppear` seed and the Quick Generation shortcut, so both paths stay
    /// identical in what profile data they apply.
    private func seedOptionsFromProfile() {
        options.dietType = session.currentUserDietaryPreference
        options.dietaryRestrictions = session.currentUserDietaryRestrictions
        options.skillLevel = session.currentUserCookingSkillLevel
        hasNoRestrictions = options.dietaryRestrictions.isEmpty
        selectedAllergies = session.currentUserAllergies
        customAllergy = session.currentUserCustomAllergy
        showAllergyOtherField = !session.currentUserCustomAllergy.isEmpty
    }

    // MARK: - Step 1: Ingredient Selection

    private var categoryChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                categoryChip(label: "All", isSelected: selectedCategories.isEmpty) {
                    selectedCategories.removeAll()
                }
                ForEach(GenCategory.allCases) { category in
                    categoryChip(label: category.label, isSelected: selectedCategories.contains(category)) {
                        if selectedCategories.count == 1 && selectedCategories.contains(category) {
                            selectedCategories.removeAll()
                        } else {
                            selectedCategories = [category]
                        }
                    }
                }
            }
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
    }

    private func categoryChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        SelectableChip(label: label, isSelected: isSelected, size: .medium, action: action)
    }

    private var ingredientSelectionView: some View {
        VStack(spacing: 0) {
            VStack(spacing: Sourdough.Spacing.rowInternals) {
                Text("Select the ingredients you'd like to use")
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: Sourdough.Spacing.insideChip) {
                    Ph.magnifyingGlass.regular
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Sourdough.Colors.faintInk)

                    TextField("Search ingredients", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.body)
                }
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .frame(height: 44)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                categoryChipsRow

                HStack {
                    Text("\(cachedFilteredIngredients.count) item\(cachedFilteredIngredients.count == 1 ? "" : "s")")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.numeric)

                    if !selectedIngredientIDs.isEmpty {
                        Button("Clear") {
                            selectedIngredientIDs.removeAll()
                        }
                        .foregroundStyle(Sourdough.Colors.actionInk)
                        .sourdoughTextStyle(.caption)
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    if !selectedIngredientIDs.isEmpty {
                        Text("\(selectedIngredientIDs.count)/15")
                            .foregroundStyle(selectedIngredientIDs.count >= 15 ? Sourdough.Colors.destructive : Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.numeric)
                    }

                    Button { showingFilterSheet = true } label: {
                        Group {
                            if hasActiveFilters {
                                Ph.fadersHorizontal.fill
                            } else {
                                Ph.fadersHorizontal.regular
                            }
                        }
                        .frame(width: 18, height: 18)
                        .foregroundStyle(
                            hasActiveFilters
                                ? Sourdough.Ramp.sage600
                                : Sourdough.Colors.mutedInk
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.rowInternals)

            if pantryStore.ingredients.isEmpty {
                Spacer()
                Text("Your pantry is empty.\nAdd ingredients from the Pantry tab first.")
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.subhead)
                    .multilineTextAlignment(.center)
                Spacer()
            } else if cachedFilteredIngredients.isEmpty {
                Spacer()
                Text("No ingredients match your filters.")
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.subhead)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: Sourdough.Spacing.insideChip) {
                        ForEach(cachedFilteredIngredients) { item in
                            ingredientSelectRow(item)
                        }
                    }
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, Sourdough.Spacing.underTitle + Sourdough.Spacing.underTitle / 3)
                }
                .disabled(isLimitExhausted)
                .opacity(isLimitExhausted ? 0.4 : 1)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [Sourdough.Colors.canvas, Sourdough.Colors.canvas.opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 48)
                    .allowsHitTesting(false)
                }
            }

            if isLimitExhausted {
                proResetTimerView
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, Sourdough.Spacing.rowInternals)
            } else {
                VStack(spacing: Sourdough.Spacing.insideChip) {
                    stepButton(label: "Continue with \(selectedIngredientIDs.count) ingredient\(selectedIngredientIDs.count == 1 ? "" : "s")", disabled: selectedIngredientIDs.isEmpty) {
                        goToStep(.options)
                    }
                    snapChefButton
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.bottom, Sourdough.Spacing.rowInternals)
            }
        }
    }

    private var snapChefButton: some View {
        Button { showSnapChef = true } label: {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                Ph.camera.bold.frame(width: 18, height: 18)
                Text("Snap Chef")
            }
            .foregroundStyle(Sourdough.Colors.action)
            .sourdoughTextStyle(.rowTitle)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Sourdough.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                    .stroke(Sourdough.Colors.action, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func ingredientSelectRow(_ item: Ingredient) -> some View {
        let isSelected = selectedIngredientIDs.contains(item.id)

        return VStack(spacing: 0) {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                Group {
                    if isSelected {
                        Ph.checkCircle.fill
                    } else {
                        Ph.circle.regular
                    }
                }
                .frame(width: 22, height: 22)
                .foregroundStyle(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.faintInk)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name.capitalized)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.body)

                    HStack(spacing: Sourdough.Spacing.insideChip) {
                        Text(item.location.title)
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)

                        if let amount = item.amount, !amount.isEmpty {
                            Text("·")
                                .foregroundStyle(Sourdough.Colors.faintInk)
                            Text(amount)
                                .foregroundStyle(Sourdough.Colors.mutedInk)
                                .sourdoughTextStyle(.caption)
                        }

                        if let days = item.daysUntilExpiration, days <= 3 {
                            Text("·")
                                .foregroundStyle(Sourdough.Colors.faintInk)
                            Text(days == 0 ? "Expires today" : "Expires in \(days)d")
                                .foregroundStyle(Sourdough.FreshnessState(daysUntilExpiration: days).style.label)
                                .sourdoughTextStyle(.caption)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.rowInternals)
            .contentShape(Rectangle())
            .onTapGesture {
                if isSelected {
                    selectedIngredientIDs.remove(item.id)
                } else {
                    guard selectedIngredientIDs.count < 15 else {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        return
                    }
                    selectedIngredientIDs.insert(item.id)
                }
            }
        }
        .background(isSelected ? Sourdough.Ramp.sage100 : Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(isSelected ? Sourdough.Ramp.sage500.opacity(0.3) : Sourdough.Colors.interactiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
    }

    // MARK: - Options Overview

    private var optionsStepView: some View {
        VStack(spacing: 0) {
            Text("Customize your recipe")
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.rowInternals)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Sourdough.Spacing.insideChip) {
                    Button { goToStep(.selectDiet) } label: {
                        OptionsRow(label: "Diet", value: options.dietType.rawValue)
                    }
                    .buttonStyle(.plain)

                    Button { goToStep(.selectRestrictions) } label: {
                        OptionsRow(
                            label: "Restrictions",
                            value: hasNoRestrictions ? "None" : options.dietaryRestrictions.map(\.rawValue).joined(separator: ", ")
                        )
                    }
                    .buttonStyle(.plain)

                    Button { goToStep(.selectAllergies) } label: {
                        let parts = selectedAllergies.map(\.rawValue) + (customAllergy.isEmpty ? [] : [customAllergy])
                        OptionsRow(label: "Allergies", value: parts.isEmpty ? "None" : parts.joined(separator: ", "))
                    }
                    .buttonStyle(.plain)

                    Button { goToStep(.selectCookTime) } label: {
                        OptionsRow(
                            label: "Cook Time",
                            value: options.maxTimeMinutes >= 60 ? "60+ min" : "\(options.maxTimeMinutes) min"
                        )
                    }
                    .buttonStyle(.plain)

                    caloriesToggleRow

                    Button { goToStep(.selectCuisine) } label: {
                        OptionsRow(label: "Cuisine", value: options.cuisine?.rawValue ?? "Any")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.bottom, Sourdough.Spacing.aboveSectionHead)
            }

            VStack(spacing: Sourdough.Spacing.rowInternals) {
                if isLimitExhausted {
                    proResetTimerView
                } else {
                    stepButton(label: "Generate Recipes", disabled: false) {
                        generationTask?.cancel()
                        generationTask = Task { await runGeneration() }
                    }
                }

                Button { goToStep(.selectIngredients, forward: false) } label: {
                    Text("Back")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.caption)
                        .padding(.vertical, Sourdough.Spacing.rowInternals)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.rowInternals)
        }
    }

    // MARK: - Selection Page Helpers

    private func selectionPageHeader(title: String) -> some View {
        HStack {
            Button { goToStep(.options, forward: false) } label: {
                Ph.caretLeft.regular
                    .frame(width: 17, height: 17)
                    .foregroundStyle(Sourdough.Colors.ink)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.title2)

            Spacer()

            Ph.caretLeft.regular
                .frame(width: 17, height: 17)
                .hidden()
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.vertical, Sourdough.Spacing.rowInternals)
    }

    private func selectionRow(
        label: String,
        isSelected: Bool,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                Group {
                    if isSelected {
                        Ph.checkCircle.fill
                    } else {
                        Ph.circle.regular
                    }
                }
                .frame(width: 20, height: 20)
                .foregroundStyle(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.faintInk)

                Text(label)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.body)

                Spacer()

                if isLocked {
                    Text("PRO")
                        .foregroundStyle(Sourdough.Colors.onAction)
                        .sourdoughTextStyle(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            LinearGradient(
                                colors: [Sourdough.Colors.action, Sourdough.Ramp.terracotta400],
                                startPoint: .topTrailing,
                                endPoint: .bottomLeading
                            )
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .frame(maxWidth: .infinity, minHeight: 60)
            .contentShape(Rectangle())
            .opacity(isLocked ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }

    // MARK: - Diet Select

    private var dietSelectView: some View {
        VStack(spacing: 0) {
            selectionPageHeader(title: "Diet")

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(GenerationOptions.DietType.allCases.enumerated()), id: \.element.id) { index, diet in
                        selectionRow(
                            label: diet.rawValue,
                            isSelected: options.dietType == diet
                        ) {
                            options.dietType = diet
                            goToStep(.options, forward: false)
                        }
                        if index < GenerationOptions.DietType.allCases.count - 1 {
                            Divider().padding(.leading, Sourdough.Spacing.screenMargin)
                        }
                    }
                }
                .padding(.top, Sourdough.Spacing.insideChip)
                .padding(.bottom, Sourdough.Spacing.aboveSectionHead)
            }
        }
    }

    // MARK: - Restrictions Select

    private var restrictionsSelectView: some View {
        VStack(spacing: 0) {
            selectionPageHeader(title: "Restrictions")

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    selectionRow(label: "None", isSelected: hasNoRestrictions) {
                        hasNoRestrictions = true
                        options.dietaryRestrictions.removeAll()
                    }
                    Divider().padding(.leading, Sourdough.Spacing.screenMargin)

                    ForEach(Array(GenerationOptions.DietaryRestriction.allCases.enumerated()), id: \.element.id) { index, restriction in
                        let isSelected = options.dietaryRestrictions.contains(restriction)
                        selectionRow(label: restriction.rawValue, isSelected: isSelected) {
                            if isSelected {
                                options.dietaryRestrictions.remove(restriction)
                                if options.dietaryRestrictions.isEmpty { hasNoRestrictions = true }
                            } else {
                                hasNoRestrictions = false
                                options.dietaryRestrictions.insert(restriction)
                            }
                        }
                        if index < GenerationOptions.DietaryRestriction.allCases.count - 1 {
                            Divider().padding(.leading, Sourdough.Spacing.screenMargin)
                        }
                    }
                }
                .padding(.top, Sourdough.Spacing.insideChip)
                .padding(.bottom, Sourdough.Spacing.aboveSectionHead)
            }
        }
    }

    // MARK: - Allergies Select

    private var allergiesSelectView: some View {
        VStack(spacing: 0) {
            selectionPageHeader(title: "Allergies")

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    let noneSelected = selectedAllergies.isEmpty && !showAllergyOtherField
                    selectionRow(label: "None", isSelected: noneSelected) {
                        selectedAllergies.removeAll()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllergyOtherField = false
                            customAllergy = ""
                        }
                    }
                    Divider().padding(.leading, Sourdough.Spacing.screenMargin)

                    ForEach(Array(AllergyType.allCases.enumerated()), id: \.element.id) { index, allergy in
                        let isSelected = selectedAllergies.contains(allergy)
                        selectionRow(label: allergy.rawValue, isSelected: isSelected) {
                            if isSelected { selectedAllergies.remove(allergy) } else { selectedAllergies.insert(allergy) }
                        }
                        Divider().padding(.leading, Sourdough.Spacing.screenMargin)
                    }

                    selectionRow(label: "Other", isSelected: showAllergyOtherField) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllergyOtherField.toggle()
                            if !showAllergyOtherField { customAllergy = "" }
                        }
                    }

                    if showAllergyOtherField {
                        TextField("Type your allergy...", text: $customAllergy)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.body)
                            .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            .frame(height: 52)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, Sourdough.Spacing.insideChip)
                .padding(.bottom, Sourdough.Spacing.aboveSectionHead)
            }
        }
    }

    // MARK: - Cook Time Select

    /// Strictest `minimumSafeCookMinutes` across currently-selected, non-expired ingredients —
    /// computed unconditionally (not just when the current time violates it) so it can both drive
    /// the auto-correcting clamp and explain an active floor even when the dial already satisfies it.
    private var safeMinimumMinutes: Int? {
        pantryStore.ingredients
            .filter { selectedIngredientIDs.contains($0.id) && !$0.isExpired }
            .compactMap(\.category.minimumSafeCookMinutes)
            .max()
    }

    private func clampCookTimeToSafeMinimum() {
        if let safeMinimumMinutes, options.maxTimeMinutes < safeMinimumMinutes {
            options.maxTimeMinutes = safeMinimumMinutes
        }
    }

    private var cookTimeSelectView: some View {
        VStack(spacing: 0) {
            selectionPageHeader(title: "Cook Time")

            Spacer()

            CircularTimeDial(minutes: $options.maxTimeMinutes)
                .frame(width: 260, height: 260)
                .onChange(of: options.maxTimeMinutes) { _, _ in clampCookTimeToSafeMinimum() }

            if let safeMinimumMinutes {
                Text("Minimum \(safeMinimumMinutes) min with raw meat, poultry, or seafood selected")
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.caption)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .padding(.top, Sourdough.Spacing.rowInternals)
            }

            Spacer()

            stepButton(label: "Save", disabled: false) {
                goToStep(.options, forward: false)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.rowInternals)
        }
        .onAppear(perform: clampCookTimeToSafeMinimum)
    }

    // MARK: - Calories Toggle Row

    private var caloriesToggleRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(spacing: 0) {
                HStack(spacing: Sourdough.Spacing.rowInternals) {
                    Text("Calories")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.body)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { caloriesEnabled },
                        set: { enabled in
                            withAnimation(DS.Motion.easeDefault) {
                                caloriesEnabled = enabled
                                options.targetCalories = enabled ? 500 : nil
                            }
                        }
                    ))
                    .labelsHidden()
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .frame(height: 52)

                if caloriesEnabled {
                    Divider()
                        .padding(.horizontal, Sourdough.Spacing.screenMargin)

                    HStack {
                        Text("Target per serving")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.subhead)
                        Spacer()
                        TextField("500", value: Binding(
                            get: { options.targetCalories ?? 500 },
                            set: { options.targetCalories = min($0, 9999) }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.body)
                        .frame(width: 60)

                        Text("cal")
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.subhead)
                    }
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.vertical, Sourdough.Spacing.rowInternals)
                }
            }
            .background(Sourdough.Colors.sunken)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                    .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
            )

            if let cal = options.targetCalories, cal > 800 {
                HStack(spacing: Sourdough.Spacing.iconToLabel) {
                    Ph.warning.fill
                        .frame(width: 12, height: 12)
                    Text("Exceeds the recommended 800 cal max per serving")
                        .foregroundStyle(Sourdough.Colors.destructive)
                        .sourdoughTextStyle(.caption)
                }
                .foregroundStyle(Sourdough.Colors.destructive)
                .padding(.horizontal, Sourdough.Spacing.insideChip)
            }
        }
    }

    // MARK: - Cuisine Select

    private var cuisineSelectView: some View {
        VStack(spacing: 0) {
            selectionPageHeader(title: "Cuisine")

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    selectionRow(label: "Any", isSelected: options.cuisine == nil) {
                        options.cuisine = nil
                        goToStep(.options, forward: false)
                    }

                    ForEach(sortedCuisines) { cuisine in
                        Divider().padding(.leading, Sourdough.Spacing.screenMargin)
                        Button {
                            options.cuisine = cuisine
                            goToStep(.options, forward: false)
                        } label: {
                            HStack(spacing: Sourdough.Spacing.rowInternals) {
                                Group {
                                    if options.cuisine == cuisine {
                                        Ph.checkCircle.fill
                                    } else {
                                        Ph.circle.regular
                                    }
                                }
                                .frame(width: 20, height: 20)
                                .foregroundStyle(options.cuisine == cuisine ? Sourdough.Ramp.sage500 : Sourdough.Colors.faintInk)

                                Text(cuisineEmoji(cuisine))
                                    .font(.system(size: 18))

                                Text(cuisine.rawValue)
                                    .foregroundStyle(Sourdough.Colors.ink)
                                    .sourdoughTextStyle(.body)

                                Spacer()
                            }
                            .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, Sourdough.Spacing.insideChip)
                .padding(.bottom, Sourdough.Spacing.aboveSectionHead)
            }
        }
    }

    private func cuisineEmoji(_ cuisine: Cuisine) -> String {
        switch cuisine {
        case .american:    return "🍔"
        case .asian:       return "🥢"
        case .chinese:     return "🥡"
        case .filipino:    return "🍖"
        case .french:      return "🥐"
        case .greek:       return "🥗"
        case .indian:      return "🍛"
        case .italian:     return "🍝"
        case .japanese:    return "🍣"
        case .korean:      return "🍲"
        case .mediterranean: return "🫒"
        case .mexican:     return "🌮"
        case .middleEastern: return "🧆"
        case .thai:        return "🌶️"
        case .spanish:     return "🥘"
        case .vietnamese:  return "🍜"
        case .brazilian:   return "🥩"
        case .ethiopian:   return "🫓"
        case .turkish:     return "🥙"
        case .peruvian:    return "🌽"
        case .caribbean:   return "🫕"
        case .other:       return "🍽️"
        }
    }

    // MARK: - Loading

    private var generatingView: some View { RecipeGenerationLoadingView() }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: 0) {
            if generationError != nil {
                errorStateView
            } else if recipes.isEmpty {
                Spacer()
                Text("No recipes generated.")
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.subhead)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: Sourdough.Spacing.rowInternals) {
                            Spacer()

                            Button {
                                generationTask?.cancel()
                                generationTask = Task { await runGeneration() }
                            } label: {
                                Label {
                                    Text("Regenerate")
                                        .foregroundStyle(Sourdough.Colors.mutedInk)
                                        .sourdoughTextStyle(.caption)
                                } icon: {
                                    Ph.arrowClockwise.regular.frame(width: 13, height: 13)
                                }
                                    .foregroundStyle(Sourdough.Colors.mutedInk)
                                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                                    .padding(.vertical, 7)
                                    .background(Sourdough.Colors.sunken)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)

                            Button {
                                goToStep(.selectIngredients, forward: false)
                                recipes = []
                                generationError = nil
                                selectedIngredientIDs.removeAll()
                            } label: {
                                Label {
                                    Text("Generate new")
                                        .foregroundStyle(Sourdough.Colors.mutedInk)
                                        .sourdoughTextStyle(.caption)
                                } icon: {
                                    Ph.sparkle.regular.frame(width: 13, height: 13)
                                }
                                    .foregroundStyle(Sourdough.Colors.mutedInk)
                                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                                    .padding(.vertical, 7)
                                    .background(Sourdough.Colors.sunken)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Sourdough.Spacing.screenMargin)
                        .padding(.top, Sourdough.Spacing.rowInternals)
                        .padding(.bottom, Sourdough.Spacing.insideChip)

                        Label {
                            Text("TOP PICK FOR YOU")
                                .foregroundStyle(Sourdough.Ramp.honey700)
                                .sourdoughTextStyle(.sectionHead)
                        } icon: {
                            Ph.lightning.fill.frame(width: 11, height: 11)
                        }
                            .foregroundStyle(Sourdough.Ramp.honey700)
                            .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            .padding(.top, Sourdough.Spacing.rowInternals)
                            .padding(.bottom, Sourdough.Spacing.insideChip)

                        NavigationLink {
                            RecipeDetailView(recipe: recipes[0])
                        } label: {
                            heroRecipeCard(recipes[0])
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Sourdough.Spacing.screenMargin)

                        if recipes.count > 1 {
                            HStack {
                                Text("More for you")
                                    .foregroundStyle(Sourdough.Colors.ink)
                                    .sourdoughTextStyle(.title2)
                                Spacer()
                            }
                            .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            .padding(.top, Sourdough.Spacing.screenMargin)
                            .padding(.bottom, Sourdough.Spacing.rowInternals)

                            VStack(spacing: Sourdough.Spacing.rowInternals) {
                                ForEach(recipes.dropFirst()) { recipe in
                                    NavigationLink {
                                        RecipeDetailView(recipe: recipe)
                                    } label: {
                                        generatedRecipeRow(recipe)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Sourdough.Spacing.screenMargin)
                            .padding(.bottom, Sourdough.Spacing.rowInternals)
                        }
                    }
                    .padding(.bottom, Sourdough.Spacing.rowInternals)
                }
            }

        }
    }

    private func heroRecipeCard(_ recipe: Recipe) -> some View {
        let tags: [String] = {
            var t: [String] = []
            if recipe.dietType != "any" { t.append(recipe.dietType.capitalized) }
            t.append(contentsOf: recipe.dietaryRestrictions)
            return Array(t.prefix(2)) + (t.count > 2 ? ["+\(t.count - 2) more"] : [])
        }()

        return OnDarkHeroCard(
            image: Image("AI_GEN"),
            title: recipe.title,
            meta: "\(recipe.macros.calories) cal · \(recipe.macros.proteinG)g protein",
            tags: tags
        ) {
            if !recipe.ingredientsUsed.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(recipe.ingredientsUsed.prefix(6), id: \.id) { ingredient in
                            Text(ingredient.name.capitalized)
                                .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                                .sourdoughTextStyle(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.bottom, Sourdough.Spacing.iconToLabel)
            }
        }
        .overlay(alignment: .topLeading) {
            AIGeneratedBadge()
                .padding(Sourdough.Spacing.rowInternals)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                let isSaved = savedRecipesStore.isSaved(recipe)
                Button {
                    if isSaved { savedRecipesStore.unsaveRecipe(recipe) }
                    else { savedRecipesStore.saveGeneratedRecipe(recipe) }
                } label: {
                    Group {
                        if isSaved {
                            Ph.bookmark.fill
                        } else {
                            Ph.bookmark.regular
                        }
                    }
                    .frame(width: 14, height: 14)
                    .foregroundStyle(isSaved ? Sourdough.Ramp.sageDark : Sourdough.Colors.heroTitleOnDark)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                timePill(recipe.timeMinutes)
            }
            .padding(Sourdough.Spacing.rowInternals)
        }
    }

    private func timePill(_ minutes: Int) -> some View {
        Label {
            Text("\(minutes) min")
                .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                .sourdoughTextStyle(.caption)
        } icon: {
            Ph.clock.regular.frame(width: 12, height: 12)
        }
            .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45))
            .clipShape(Capsule())
    }

    private func generatedRecipeRow(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            HStack(spacing: 4) {
                Ph.sparkle.regular
                    .frame(width: 10, height: 10)
                Text("AI Generated")
                    .foregroundStyle(Sourdough.Colors.onAction)
                    .sourdoughTextStyle(.caption)
            }
            .foregroundStyle(Sourdough.Colors.onAction)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [Sourdough.Colors.action, Sourdough.Ramp.terracotta400],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())

            HStack(alignment: .top, spacing: Sourdough.Spacing.insideChip) {
                Text(recipe.title)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.rowTitle)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let isSaved = savedRecipesStore.isSaved(recipe)
                Button {
                    if isSaved { savedRecipesStore.unsaveRecipe(recipe) }
                    else { savedRecipesStore.saveGeneratedRecipe(recipe) }
                } label: {
                    Group {
                        if isSaved {
                            Ph.bookmark.fill
                        } else {
                            Ph.bookmark.regular
                        }
                    }
                    .frame(width: 15, height: 15)
                    .foregroundStyle(isSaved ? Sourdough.Ramp.sage500 : Sourdough.Colors.mutedInk)
                }
                .buttonStyle(.plain)
            }

            Label {
                Text("\(recipe.timeMinutes) min")
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.subhead)
            } icon: {
                Ph.clock.regular.frame(width: 13, height: 13)
            }
                .foregroundStyle(Sourdough.Colors.mutedInk)

            if !recipe.ingredientsUsed.isEmpty {
                let displayed = Array(recipe.ingredientsUsed.prefix(5))
                let overflow = recipe.ingredientsUsed.count - displayed.count
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(displayed, id: \.id) { ing in
                            ingredientChip(ing.name)
                        }
                        if overflow > 0 {
                            ingredientChip("+\(overflow) more")
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(Sourdough.Spacing.screenMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
    }

    private func ingredientChip(_ text: String) -> some View {
        Text(text.capitalized)
            .foregroundStyle(Sourdough.Colors.onAction)
            .sourdoughTextStyle(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Sourdough.Ramp.sage500)
            .clipShape(Capsule())
    }

    // MARK: - Pro Reset Timer

    @ViewBuilder
    private var proResetTimerView: some View {
        VStack(spacing: 4) {
            Text("Daily limit reached")
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.subhead)

            if let resetDate = activityStore.nextDailyResetDate {
                HStack(spacing: Sourdough.Spacing.insideChip) {
                    Ph.clock.regular
                        .frame(width: 14, height: 14)
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let remaining = max(0, resetDate.timeIntervalSince(ctx.date))
                        Text(formatCountdown(remaining))
                            .sourdoughTextStyle(.numeric)
                    }
                    Text("until next 5")
                        .sourdoughTextStyle(.caption)
                }
                .foregroundStyle(Sourdough.Colors.ink)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Sourdough.Colors.sunken)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
        )
    }

    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    // MARK: - Generation Count Row

    private var generationCountRow: some View {
        let remaining = max(0, 5 - activityStore.generationsToday)
        let label = "\(remaining) Generation\(remaining == 1 ? "" : "s") left for the day"

        return HStack(spacing: Sourdough.Spacing.insideChip) {
            HStack(spacing: 4) {
                Ph.lightning.fill
                    .frame(width: 13, height: 13)
                Text(label)
                    .foregroundStyle(Sourdough.Colors.onAction)
                    .sourdoughTextStyle(.subhead)
            }
            .foregroundStyle(Sourdough.Colors.onAction)
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Sourdough.Ramp.sage600, Sourdough.Ramp.sage500],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())

            Spacer()
        }
    }

    // MARK: - Navigation Helpers

    private func stepButton(label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .foregroundStyle(Sourdough.Colors.onAction)
                .sourdoughTextStyle(.rowTitle)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Sourdough.Colors.action)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    // MARK: - Generation

    // MARK: - Error State

    private var errorIcon: Image {
        switch generationError as? RecipeGenerationError {
        case .apiError: return Ph.wifiSlash.regular
        case .emptyResponse: return Ph.tray.regular
        default: return Ph.warning.regular
        }
    }

    private var errorTitle: String {
        switch generationError as? RecipeGenerationError {
        case .apiError: return "Our Chef Must Be Busy!"
        case .parsingError: return "Unexpected response"
        case .emptyResponse: return "No recipes found"
        default: return "Something went wrong"
        }
    }

    private var errorMessage: String {
        switch generationError as? RecipeGenerationError {
        case .apiError: return "Check your connection and tap Try Again."
        case .parsingError: return "Our Chef returned an unexpected response. Please try again."
        case .emptyResponse: return "No recipes were generated. Try selecting more ingredients or adjusting your options."
        default: return "An unexpected error occurred. Please try again."
        }
    }

    private var errorStateView: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            Spacer()
            errorIcon
                .frame(width: 52, height: 52)
                .foregroundStyle(Sourdough.Colors.destructive)
            VStack(spacing: Sourdough.Spacing.insideChip) {
                Text(errorTitle)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.title1)
                    .multilineTextAlignment(.center)
                Text(errorMessage)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Sourdough.Spacing.betweenBlocks)
            }
            Spacer()
            VStack(spacing: Sourdough.Spacing.rowInternals) {
                Button {
                    generationTask?.cancel()
                    generationTask = Task { await runGeneration() }
                } label: {
                    Text("Try Again")
                        .foregroundStyle(Sourdough.Colors.onAction)
                        .sourdoughTextStyle(.rowTitle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Sourdough.Colors.action)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    goToStep(.selectIngredients, forward: false)
                    recipes = []
                    generationError = nil
                    selectedIngredientIDs.removeAll()
                } label: {
                    Text("Change Ingredients")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.caption)
                        .padding(.vertical, Sourdough.Spacing.rowInternals)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.rowInternals)
        }
    }

    @MainActor
    private func runGeneration() async {
        guard session.isPremium else {
            showPaywall = true
            return
        }

        generationError = nil

        goToStep(.loading)

        // Safety net for `options.maxTimeMinutes` in case the user never revisited the Cook Time
        // step after changing ingredient selection — see `clampCookTimeToSafeMinimum()`.
        clampCookTimeToSafeMinimum()

        let names: [String] = pantryStore.ingredients
            .filter { selectedIngredientIDs.contains($0.id) && !$0.isExpired }
            .map { ingredient in
                if let amount = ingredient.totalAmount, !amount.isEmpty {
                    return "\(ingredient.name) (\(amount))"
                }
                return ingredient.name
            }

        var parts = selectedAllergies.map(\.rawValue)
        if !customAllergy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(customAllergy.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        options.allergies = parts

        options.priorityIngredients = pantryStore.ingredients
            .filter { selectedIngredientIDs.contains($0.id) && !$0.isExpired && $0.isExpiringSoon }
            .map { $0.name }

        options.diversifyIngredients = true

        do {
            recipes = try await recipeGenerator.generateRecipes(
                for: names,
                options: options
            )
            // The edge function records the `recipe_generated` row server-side; just reconcile.
            activityStore.noteRecipeGeneratedRemotely()
            goToStep(.results)
        } catch RecipeGenerationError.limitExhausted {
            recipes = []
            // Server rejected on quota — resync the counter so the UI reflects the real limit state.
            await activityStore.fetchGenerationsToday()
            goToStep(.selectIngredients, forward: false)
        } catch {
            recipes = []
            generationError = error
            goToStep(.results)
        }
    }
}

// MARK: - Generate Step

private enum GenerateStep {
    case selectIngredients
    case options
    case selectDiet
    case selectRestrictions
    case selectAllergies
    case selectCookTime
    case selectCuisine
    case loading
    case results
}

// MARK: - Options Row

private struct OptionsRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            Text(label)
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.body)
            Spacer()
            Text(value)
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.subhead)
                .lineLimit(1)
            Ph.caretRight.regular
                .frame(width: 12, height: 12)
                .foregroundStyle(Sourdough.Colors.faintInk)
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .frame(height: 52)
        .background(Sourdough.Colors.sunken)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
        )
    }
}

// MARK: - Circular Time Dial

private struct CircularTimeDial: View {
    @Binding var minutes: Int

    private let minMinutes = 10
    private let maxMinutes = 60
    private let stepSize = 5

    private var progress: Double {
        Double(minutes - minMinutes) / Double(maxMinutes - minMinutes)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2 - 20
            let thumbAngleDeg = -90.0 + progress * 360.0
            let thumbAngle = Angle.degrees(thumbAngleDeg)
            let thumbPoint = CGPoint(
                x: center.x + radius * CGFloat(Foundation.cos(thumbAngle.radians)),
                y: center.y + radius * CGFloat(Foundation.sin(thumbAngle.radians))
            )

            ZStack {
                Circle()
                    .stroke(Sourdough.Colors.interactiveBorder, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: radius * 2, height: radius * 2)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Sourdough.Colors.action, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: radius * 2, height: radius * 2)

                VStack(spacing: 2) {
                    Text(minutes >= maxMinutes ? "60+" : "\(minutes)")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.display)
                    Text("min")
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                        .sourdoughTextStyle(.caption)
                }

                Circle()
                    .fill(Sourdough.Colors.action)
                .frame(width: 28, height: 28)
                    .shadow(color: Sourdough.Colors.action.opacity(0.3), radius: 4, x: 0, y: 2)
                    .position(thumbPoint)
            }
            .frame(width: size, height: size)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                        var angleDeg = atan2(vector.dy, vector.dx) * 180 / .pi + 90
                        if angleDeg < 0 { angleDeg += 360 }
                        let newProgress = angleDeg / 360.0
                        let rawMinutes = Double(minMinutes) + newProgress * Double(maxMinutes - minMinutes)
                        let snapped = Int((rawMinutes / Double(stepSize)).rounded()) * stepSize
                        minutes = max(minMinutes, min(maxMinutes, snapped))
                    }
            )
        }
    }
}

// MARK: - Filter Enums

private enum GenCategory: String, CaseIterable, Identifiable {
    case proteins, seafood, vegetables, carbs, dairy, fruits, condiments, other

    var id: String { rawValue }

    var label: String { ingredientCategory.title }
    var icon: Image {
        switch self {
        case .proteins:   return Ph.hamburger.regular
        case .seafood:    return Ph.fish.regular
        case .vegetables: return Ph.leaf.regular
        case .carbs:      return Ph.bread.regular
        case .dairy:      return Ph.coffee.regular
        case .fruits:     return Ph.orangeSlice.regular
        case .condiments: return Ph.jar.regular
        case .other:      return Ph.package.regular
        }
    }

    var ingredientCategory: Ingredient.Category {
        switch self {
        case .proteins:   return .proteins
        case .seafood:    return .seafood
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
    @Binding var selectedStorageFilters: Set<IngredientStorageFilter>
    @Binding var selectedCategories: Set<GenCategory>

    private var hasActiveFilters: Bool {
        !selectedStorageFilters.isEmpty || !selectedCategories.isEmpty
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
                                selectedStorageFilters.removeAll()
                                selectedCategories.removeAll()
                            } label: {
                                Text("Reset")
                                    .foregroundStyle(Sourdough.Colors.actionInk)
                                    .sourdoughTextStyle(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                        Text("STORAGE")
                            .foregroundStyle(Sourdough.Colors.faintInk)
                            .sourdoughTextStyle(.sectionHead)

                        VStack(spacing: Sourdough.Spacing.insideChip) {
                            ForEach(IngredientStorageFilter.allCases) { filter in
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

                    VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
                        Text("CATEGORY")
                            .foregroundStyle(Sourdough.Colors.faintInk)
                            .sourdoughTextStyle(.sectionHead)

                        VStack(spacing: Sourdough.Spacing.insideChip) {
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
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            Button { dismiss() } label: {
                Text("Apply Filters")
                    .foregroundStyle(Sourdough.Colors.onAction)
                    .sourdoughTextStyle(.rowTitle)
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

    private func filterRow(
        icon: Image,
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                Group {
                    if isSelected {
                        Ph.checkCircle.fill
                    } else {
                        Ph.circle.regular
                    }
                }
                .frame(width: 20, height: 20)
                .foregroundStyle(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.faintInk)

                icon
                    .frame(width: 18, height: 18)
                    .foregroundStyle(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.mutedInk)
                    .frame(width: 24)

                Text(label)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .sourdoughTextStyle(.body)

                Spacer()
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .frame(height: 48)
            .background(isSelected ? Sourdough.Ramp.sage100 : Sourdough.Colors.sunken)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                    .stroke(isSelected ? Sourdough.Ramp.sage500.opacity(0.3) : Sourdough.Colors.interactiveBorder, lineWidth: 1)
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
