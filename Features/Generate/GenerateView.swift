import SwiftUI
import RevenueCatUI

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
    @State private var selectedStorageFilters: Set<GenStorageFilter> = []
    @State private var selectedCategories: Set<GenCategory> = []
    @State private var showingFilterSheet = false
    @State private var options = GenerationOptions()
    @State private var recipes: [Recipe] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var step: GenerateStep = .selectIngredients
    @State private var noneRestrictions = true
    @State private var showingSettings = false
    @State private var showPaywall = false

    private var hasActiveFilters: Bool {
        !selectedStorageFilters.isEmpty || !selectedCategories.isEmpty
    }

    private var isLimitExhausted: Bool {
        !session.isPremium && activityStore.generationsThisWeek >= 10
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

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.space4) {
                Text("Generate")
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

            if !session.isPremium {
                generationLimitBanner
            }

            switch step {
            case .selectIngredients:
                ingredientSelectionView
            case .dietType:
                dietTypeView
            case .dietaryRestrictions:
                dietaryRestrictionsView
            case .cookingTime:
                cookingTimeView
            case .calorieTarget:
                calorieTargetView
            case .cuisineType:
                cuisineTypeView
            case .loading:
                generatingView
            case .results:
                resultsView
            }
        }
        .background(DS.ColorToken.bgPrimary)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 80)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .onPurchaseCompleted { _ in
                    showPaywall = false
                }
                .onRestoreCompleted { _ in
                    showPaywall = false
                }
        }
        .sheet(isPresented: $showingFilterSheet) {
            GenFilterSheet(
                selectedStorageFilters: $selectedStorageFilters,
                selectedCategories: $selectedCategories
            )
            .presentationDetents([.large])
        }
        .task {
            await activityStore.fetchGenerationsThisWeek()
            if isLimitExhausted { showPaywall = true }
        }
        .onChange(of: activityStore.generationsThisWeek) { _, _ in
            if isLimitExhausted { showPaywall = true }
        }
        .onAppear {
            options.dietType = session.currentUserDietaryPreference
            options.dietaryRestrictions = session.currentUserDietaryRestrictions
            options.skillLevel = session.currentUserCookingSkillLevel
            noneRestrictions = options.dietaryRestrictions.isEmpty
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

    private func goToStep(_ newStep: GenerateStep) {
        withAnimation(.easeInOut(duration: 0.25)) {
            step = newStep
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

            if pantryStore.ingredients.isEmpty {
                Spacer()
                Text("Your pantry is empty.\nAdd ingredients from the Pantry tab first.")
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .multilineTextAlignment(.center)
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
                .disabled(isLimitExhausted)
                .opacity(isLimitExhausted ? 0.4 : 1)
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

            if isLimitExhausted {
                Button { showPaywall = true } label: {
                    HStack(spacing: DS.Spacing.space2) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Upgrade to Pro for unlimited recipes")
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
                .padding(.bottom, DS.Spacing.space4)
            } else {
                stepButton(label: "Continue with \(selectedIngredientIDs.count) ingredient\(selectedIngredientIDs.count == 1 ? "" : "s")", disabled: selectedIngredientIDs.isEmpty) {
                    goToStep(.dietType)
                }
                .padding(.horizontal, DS.Spacing.space5)
                .padding(.bottom, DS.Spacing.space4)
            }
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
            .background(isSelected ? DS.ColorToken.accentLight : DS.ColorToken.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(isSelected ? DS.ColorToken.accent.opacity(0.3) : DS.ColorToken.borderDefault, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: Diet Type

    private var dietTypeView: some View {
        VStack(spacing: 0) {
            Text("What's your diet?")
                .font(.custom("Satoshi Variable", size: 18).weight(.medium))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.space5)
                .padding(.top, DS.Spacing.space3)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.space3), GridItem(.flexible(), spacing: DS.Spacing.space3)], spacing: DS.Spacing.space3) {
                    ForEach(GenerationOptions.DietType.allCases) { diet in
                        let isSelected = options.dietType == diet
                        let isLocked = !session.isPremium && diet != .any && diet != session.currentUserDietaryPreference
                        Button {
                            if !isLocked { options.dietType = diet }
                        } label: {
                            VStack(spacing: DS.Spacing.space3) {
                                Image(systemName: isLocked ? "lock.fill" : dietTypeIcon(diet))
                                    .font(.system(size: 32))
                                    .foregroundStyle(isSelected ? DS.ColorToken.accent : DS.ColorToken.textSecondary)

                                Text(diet.rawValue)
                                    .font(.custom("Satoshi Variable", size: 15).weight(.semibold))
                                    .foregroundStyle(isSelected ? DS.ColorToken.accent : DS.ColorToken.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(isSelected ? DS.ColorToken.accentLight : DS.ColorToken.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                                    .stroke(isSelected ? DS.ColorToken.accent : DS.ColorToken.borderDefault, lineWidth: isSelected ? 2 : 1)
                            )
                            .overlay(alignment: .topTrailing) {
                                if isLocked {
                                    Text("PRO")
                                        .font(.custom("Satoshi Variable", size: 9).weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            LinearGradient(
                                                colors: [DS.ColorToken.berry, DS.ColorToken.lavender],
                                                startPoint: .topTrailing,
                                                endPoint: .bottomLeading
                                            )
                                        )
                                        .clipShape(Capsule())
                                        .padding(8)
                                }
                            }
                            .opacity(isLocked ? 0.4 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLocked)
                    }
                }
                .padding(.horizontal, DS.Spacing.space5)
                .padding(.top, DS.Spacing.space4)
                .padding(.bottom, DS.Spacing.space8)
            }

            Spacer()

            stepNavButtons(back: .selectIngredients, next: .dietaryRestrictions)
        }
    }

    private func dietTypeIcon(_ diet: GenerationOptions.DietType) -> String {
        switch diet {
        case .any: return "fork.knife"
        case .vegetarian: return "leaf.fill"
        case .vegan: return "leaf.circle.fill"
        case .pescatarian: return "fish.fill"
        case .keto: return "flame.fill"
        case .paleo: return "hare.fill"
        }
    }

    // MARK: - Step 3: Dietary Restrictions

    private var dietaryRestrictionsView: some View {
        VStack(spacing: 0) {
            Text("Any dietary restrictions?")
                .font(.custom("Satoshi Variable", size: 18).weight(.medium))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.space5)
                .padding(.top, DS.Spacing.space3)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.space3), GridItem(.flexible(), spacing: DS.Spacing.space3)], spacing: DS.Spacing.space3) {
                    // None option
                    Button {
                        noneRestrictions = true
                        options.dietaryRestrictions.removeAll()
                    } label: {
                        VStack(spacing: DS.Spacing.space3) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(noneRestrictions ? DS.ColorToken.accent : DS.ColorToken.textSecondary)

                            Text("None")
                                .font(.custom("Satoshi Variable", size: 15).weight(.semibold))
                                .foregroundStyle(noneRestrictions ? DS.ColorToken.accent : DS.ColorToken.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(noneRestrictions ? DS.ColorToken.accentLight : DS.ColorToken.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                                .stroke(noneRestrictions ? DS.ColorToken.accent : DS.ColorToken.borderDefault, lineWidth: noneRestrictions ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(GenerationOptions.DietaryRestriction.allCases) { restriction in
                        let isSelected = options.dietaryRestrictions.contains(restriction)
                        let isLocked = !session.isPremium && !session.currentUserDietaryRestrictions.contains(restriction)
                        Button {
                            if isLocked { return }
                            if isSelected {
                                options.dietaryRestrictions.remove(restriction)
                                if options.dietaryRestrictions.isEmpty {
                                    noneRestrictions = true
                                }
                            } else {
                                noneRestrictions = false
                                options.dietaryRestrictions.insert(restriction)
                            }
                        } label: {
                            VStack(spacing: DS.Spacing.space3) {
                                Image(systemName: isLocked ? "lock.fill" : restrictionIcon(restriction))
                                    .font(.system(size: 32))
                                    .foregroundStyle(isSelected ? DS.ColorToken.accent : DS.ColorToken.textSecondary)

                                Text(restriction.rawValue)
                                    .font(.custom("Satoshi Variable", size: 14).weight(.semibold))
                                    .foregroundStyle(isSelected ? DS.ColorToken.accent : DS.ColorToken.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(isSelected ? DS.ColorToken.accentLight : DS.ColorToken.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                                    .stroke(isSelected ? DS.ColorToken.accent : DS.ColorToken.borderDefault, lineWidth: isSelected ? 2 : 1)
                            )
                            .overlay(alignment: .topTrailing) {
                                if isLocked {
                                    Text("PRO")
                                        .font(.custom("Satoshi Variable", size: 9).weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            LinearGradient(
                                                colors: [DS.ColorToken.berry, DS.ColorToken.lavender],
                                                startPoint: .topTrailing,
                                                endPoint: .bottomLeading
                                            )
                                        )
                                        .clipShape(Capsule())
                                        .padding(8)
                                }
                            }
                            .opacity(isLocked ? 0.4 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLocked)
                    }
                }
                .padding(.horizontal, DS.Spacing.space5)
                .padding(.top, DS.Spacing.space4)
                .padding(.bottom, DS.Spacing.space8)
            }

            Spacer()

            stepNavButtons(back: .dietType, next: session.isPremium ? .cookingTime : .cuisineType)
        }
    }

    private func restrictionIcon(_ restriction: GenerationOptions.DietaryRestriction) -> String {
        switch restriction {
        case .glutenFree: return "xmark.circle"
        case .nutFree: return "leaf.arrow.triangle.circlepath"
        case .dairyFree: return "cup.and.saucer"
        case .soyFree: return "drop.circle"
        case .eggFree: return "oval"
        case .shellfishFree: return "fish"
        case .lowSodium: return "bolt.heart"
        }
    }

    // MARK: - Step 4: Cooking Time

    private var cookingTimeView: some View {
        VStack(spacing: 0) {
            Text("Max cooking time")
                .font(.custom("Satoshi Variable", size: 18).weight(.medium))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.space5)
                .padding(.top, DS.Spacing.space3)

            Spacer()

            if session.isPremium {
                CircularTimeDial(minutes: $options.maxTimeMinutes)
                    .frame(width: 260, height: 260)
            } else {
                VStack(spacing: DS.Spacing.space4) {
                    ZStack {
                        CircularTimeDial(minutes: .constant(30))
                            .frame(width: 260, height: 260)
                            .opacity(0.3)
                            .allowsHitTesting(false)

                        VStack(spacing: DS.Spacing.space2) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(DS.ColorToken.textTertiary)

                            Text("PRO")
                                .font(.custom("Satoshi Variable", size: 13).weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        colors: [DS.ColorToken.berry, DS.ColorToken.lavender],
                                        startPoint: .topTrailing,
                                        endPoint: .bottomLeading
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }

                    Text("Default cooking time will be used")
                        .font(.custom("Satoshi Variable", size: 13))
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }
            }

            Spacer()

            stepNavButtons(back: .dietaryRestrictions, next: .calorieTarget)
        }
    }

    // MARK: - Step 5: Calorie Target

    private var calorieTargetView: some View {
        VStack(spacing: 0) {
            Text("Calorie target per serving")
                .font(.custom("Satoshi Variable", size: 18).weight(.medium))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.space5)
                .padding(.top, DS.Spacing.space3)

            Spacer()

            if session.isPremium {
                VStack(spacing: DS.Spacing.space4) {
                    TextField("500", value: Binding(
                        get: { options.targetCalories ?? 500 },
                        set: { options.targetCalories = min($0, 9999) }
                    ), format: .number)
                    .onChange(of: options.targetCalories) { _, newValue in
                        if let val = newValue, val > 9999 {
                            options.targetCalories = 9999
                        }
                    }
                    .keyboardType(.numberPad)
                    .font(.custom("CalSans-Regular", size: 48))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(width: 200)

                    Text("calories per serving")
                        .font(.custom("Satoshi Variable", size: 16).weight(.medium))
                        .foregroundStyle(DS.ColorToken.textSecondary)

                    if let cal = options.targetCalories, cal > 800 {
                        HStack(spacing: DS.Spacing.space1) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("Exceeds the recommended 800 cal max per serving")
                                .font(.custom("Satoshi Variable", size: 13))
                        }
                        .foregroundStyle(DS.ColorToken.error)
                        .multilineTextAlignment(.center)
                    }
                }
            } else {
                VStack(spacing: DS.Spacing.space4) {
                    ZStack {
                        VStack(spacing: DS.Spacing.space2) {
                            Text("500")
                                .font(.custom("CalSans-Regular", size: 48))
                                .foregroundStyle(DS.ColorToken.textPrimary)
                            Text("calories")
                                .font(.custom("Satoshi Variable", size: 16).weight(.medium))
                                .foregroundStyle(DS.ColorToken.textSecondary)
                        }
                        .opacity(0.3)

                        VStack(spacing: DS.Spacing.space2) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(DS.ColorToken.textTertiary)

                            Text("PRO")
                                .font(.custom("Satoshi Variable", size: 13).weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        colors: [DS.ColorToken.berry, DS.ColorToken.lavender],
                                        startPoint: .topTrailing,
                                        endPoint: .bottomLeading
                                    )
                                )
                                .clipShape(Capsule())
                        }
                    }

                    Text("Default calories will be used")
                        .font(.custom("Satoshi Variable", size: 13))
                        .foregroundStyle(DS.ColorToken.textTertiary)
                }
            }

            Spacer()

            VStack(spacing: DS.Spacing.space3) {
                stepButton(label: "Next", disabled: (options.targetCalories ?? 0) > 800) {
                    goToStep(.cuisineType)
                }

                Button {
                    options.targetCalories = nil
                    goToStep(.cuisineType)
                } label: {
                    Text("Skip")
                        .font(.custom("Satoshi Variable", size: 15).weight(.semibold))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { goToStep(.cookingTime) } label: {
                    Text("Back")
                        .font(.custom("Satoshi Variable", size: 14))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .padding(.vertical, DS.Spacing.space3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.bottom, DS.Spacing.space4)
        }
    }

    // MARK: - Step 6: Cuisine Type

    private var cuisineTypeView: some View {
        VStack(spacing: 0) {
            Text("Preferred cuisine")
                .font(.custom("Satoshi Variable", size: 18).weight(.medium))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.space5)
                .padding(.top, DS.Spacing.space3)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.space3), GridItem(.flexible(), spacing: DS.Spacing.space3)], spacing: DS.Spacing.space3) {
                    // Any option
                    let anySelected = options.cuisine == nil
                    Button {
                        options.cuisine = nil
                    } label: {
                        VStack(spacing: DS.Spacing.space3) {
                            Image(systemName: "globe")
                                .font(.system(size: 32))
                                .foregroundStyle(anySelected ? DS.ColorToken.accent : DS.ColorToken.textSecondary)

                            Text("Any")
                                .font(.custom("Satoshi Variable", size: 15).weight(.semibold))
                                .foregroundStyle(anySelected ? DS.ColorToken.accent : DS.ColorToken.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(anySelected ? DS.ColorToken.accentLight : DS.ColorToken.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                                .stroke(anySelected ? DS.ColorToken.accent : DS.ColorToken.borderDefault, lineWidth: anySelected ? 2 : 1)
                        )
                    }
                    .buttonStyle(.plain)

                    let freeCuisines: Set<Cuisine> = [
                        .american, .asian, .caribbean,
                        .french, .greek, .indian, .italian,
                        .mediterranean, .middleEastern, .spanish
                    ]
                    let sortedCuisines = Cuisine.allCases.filter { $0 != .other }.sorted { lhs, rhs in
                        if !session.isPremium {
                            let lhsFree = freeCuisines.contains(lhs)
                            let rhsFree = freeCuisines.contains(rhs)
                            if lhsFree != rhsFree { return lhsFree }
                        }
                        return false
                    }

                    ForEach(sortedCuisines) { cuisine in
                        let isSelected = options.cuisine == cuisine
                        let isLocked = !session.isPremium && !freeCuisines.contains(cuisine)
                        Button {
                            if !isLocked { options.cuisine = cuisine }
                        } label: {
                            VStack(spacing: DS.Spacing.space3) {
                                if isLocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(DS.ColorToken.textSecondary)
                                } else {
                                    Text(cuisineEmoji(cuisine))
                                        .font(.system(size: 32))
                                }

                                Text(cuisine.rawValue)
                                    .font(.custom("Satoshi Variable", size: 14).weight(.semibold))
                                    .foregroundStyle(isSelected ? DS.ColorToken.accent : DS.ColorToken.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(isSelected ? DS.ColorToken.accentLight : DS.ColorToken.bgSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                                    .stroke(isSelected ? DS.ColorToken.accent : DS.ColorToken.borderDefault, lineWidth: isSelected ? 2 : 1)
                            )
                            .overlay(alignment: .topTrailing) {
                                if isLocked {
                                    Text("PRO")
                                        .font(.custom("Satoshi Variable", size: 9).weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            LinearGradient(
                                                colors: [DS.ColorToken.berry, DS.ColorToken.lavender],
                                                startPoint: .topTrailing,
                                                endPoint: .bottomLeading
                                            )
                                        )
                                        .clipShape(Capsule())
                                        .padding(8)
                                }
                            }
                            .opacity(isLocked ? 0.4 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLocked)
                    }
                }
                .padding(.horizontal, DS.Spacing.space5)
                .padding(.top, DS.Spacing.space4)
                .padding(.bottom, DS.Spacing.space8)
            }

            Spacer()

            // Generate button instead of Next
            VStack(spacing: DS.Spacing.space3) {
                if !session.isPremium && activityStore.generationsThisWeek >= 10 {
                    Text("You've used all 10 free generations this week")
                        .font(.custom("Satoshi Variable", size: 13))
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
                } else {
                    stepButton(label: "Generate Recipes", disabled: false) {
                        generationTask?.cancel()
                        generationTask = Task { await runGeneration() }
                    }
                }

                Button { goToStep(session.isPremium ? .calorieTarget : .dietaryRestrictions) } label: {
                    Text("Back")
                        .font(.custom("Satoshi Variable", size: 14))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .padding(.vertical, DS.Spacing.space3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.bottom, DS.Spacing.space4)
        }
    }

    private func cuisineEmoji(_ cuisine: Cuisine) -> String {
        switch cuisine {
        case .american: return "🍔"
        case .asian: return "🥢"
        case .chinese: return "🥡"
        case .filipino: return "🍖"
        case .french: return "🥐"
        case .greek: return "🥗"
        case .indian: return "🍛"
        case .italian: return "🍝"
        case .japanese: return "🍣"
        case .korean: return "🍲"
        case .mediterranean: return "🫒"
        case .mexican: return "🌮"
        case .middleEastern: return "🧆"
        case .thai: return "🌶️"
        case .spanish: return "🥘"
        case .vietnamese: return "🍜"
        case .brazilian: return "🥩"
        case .ethiopian: return "🫓"
        case .turkish: return "🥙"
        case .peruvian: return "🌽"
        case .caribbean: return "🫕"
        case .other: return "🍽️"
        }
    }

    // MARK: - Loading

    private var generatingView: some View {
        VStack(spacing: DS.Spacing.space4) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .tint(DS.ColorToken.primary)

            Text("Let me cook...")
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

    // MARK: - Results

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
                    VStack(alignment: .leading, spacing: 0) {
                        Label("TOP PICK FOR YOU", systemImage: "bolt.fill")
                            .font(.custom("Satoshi Variable", size: 11).weight(.bold))
                            .foregroundStyle(DS.ColorToken.accent)
                            .padding(.horizontal, DS.Spacing.space5)
                            .padding(.top, DS.Spacing.space3)
                            .padding(.bottom, DS.Spacing.space2)

                        NavigationLink {
                            RecipeDetailView(recipe: recipes[0])
                        } label: {
                            heroRecipeCard(recipes[0])
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, DS.Spacing.space5)

                        if recipes.count > 1 {
                            HStack {
                                Text("More for you")
                                    .appTextStyle(.heading3)
                                    .foregroundStyle(DS.ColorToken.textPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, DS.Spacing.space5)
                            .padding(.top, DS.Spacing.space5)
                            .padding(.bottom, DS.Spacing.space3)

                            VStack(spacing: DS.Spacing.space3) {
                                ForEach(recipes.dropFirst()) { recipe in
                                    NavigationLink {
                                        RecipeDetailView(recipe: recipe)
                                    } label: {
                                        listRecipeRow(recipe)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, DS.Spacing.space5)
                        }
                    }
                    .padding(.bottom, DS.Spacing.space4)
                }
            }

            VStack(spacing: DS.Spacing.space2) {
                Button {
                    generationTask?.cancel()
                    generationTask = Task { await runGeneration() }
                } label: {
                    Label("Regenerate suggestions", systemImage: "bolt.fill")
                        .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(DS.ColorToken.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        step = .selectIngredients
                        recipes = []
                        errorText = nil
                    }
                } label: {
                    Text("Start Over")
                        .font(.custom("Satoshi Variable", size: 16))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.space3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space4)
        }
    }

    private func heroRecipeCard(_ recipe: Recipe) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image("AI_GEN")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 260)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                Text(recipe.title)
                    .font(.custom("CalSans-Regular", size: 22))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: DS.Spacing.space2) {
                    Label("\(recipe.macros.calories) cal", systemImage: "bolt.fill")
                    Text("·").foregroundStyle(.white.opacity(0.6))
                    Label("\(recipe.macros.proteinG)g protein", systemImage: "heart.fill")
                    Text("·").foregroundStyle(.white.opacity(0.6))
                    Text("uses \(recipe.ingredientsUsed.count)")
                }
                .font(.custom("Satoshi Variable", size: 12))
                .foregroundStyle(.white.opacity(0.85))
            }
            .padding(DS.Spacing.space4)
        }
        .overlay(alignment: .topTrailing) {
            timePill(recipe.timeMinutes)
                .padding(DS.Spacing.space3)
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }

    private func listRecipeRow(_ recipe: Recipe) -> some View {
        HStack(spacing: DS.Spacing.space3) {
            Image("AI_GEN")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 72, height: 72)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(recipeTag(for: recipe))
                    .font(.custom("Satoshi Variable", size: 10).weight(.bold))
                    .foregroundStyle(DS.ColorToken.accent)
                    .tracking(0.5)

                Text(recipe.title)
                    .appTextStyle(.bodySM)
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Label("\(recipe.timeMinutes) min", systemImage: "clock")
                    Text("·").foregroundStyle(DS.ColorToken.textTertiary)
                    Text("\(recipe.macros.calories)")
                    if !recipe.ingredientsUsed.isEmpty {
                        Text("·").foregroundStyle(DS.ColorToken.textTertiary)
                        Text(recipe.ingredientsUsed.prefix(2).map { $0.name.capitalized }.joined(separator: ", "))
                    }
                }
                .font(.custom("Satoshi Variable", size: 11))
                .foregroundStyle(DS.ColorToken.textTertiary)
                .lineLimit(1)
            }

            Spacer()

            Button {
                if session.isPremium {
                    if savedRecipesStore.isSaved(recipe) {
                        savedRecipesStore.unsaveRecipe(recipe)
                    } else {
                        savedRecipesStore.saveRecipe(recipe)
                    }
                } else {
                    showPaywall = true
                }
            } label: {
                Image(systemName: savedRecipesStore.isSaved(recipe) ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        savedRecipesStore.isSaved(recipe) ? DS.ColorToken.primary : DS.ColorToken.textTertiary
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.space3)
        .background(DS.ColorToken.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
        )
    }

    private func recipeTag(for recipe: Recipe) -> String {
        if recipe.macros.proteinG >= 25 { return "HIGH PROTEIN" }
        if recipe.timeMinutes <= 15 { return "QUICK" }
        if recipe.macros.carbsG <= 20 { return "LOW CARB" }
        return "COMFORTING"
    }

    private func timePill(_ minutes: Int) -> some View {
        Label("\(minutes) min", systemImage: "clock")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45))
            .clipShape(Capsule())
    }

    // MARK: - Generation Limit Banner

    private var generationLimitBanner: some View {
        let remaining = max(0, 10 - activityStore.generationsThisWeek)
        let exhausted = remaining == 0

        return HStack(spacing: DS.Spacing.space3) {
            Image(systemName: exhausted ? "exclamationmark.triangle.fill" : "bolt.fill")
                .font(.system(size: 16))
                .foregroundStyle(exhausted ? DS.ColorToken.error : DS.ColorToken.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text(exhausted ? "No free generations remaining" : "\(remaining) of 10 free generation\(remaining == 1 ? "" : "s") remaining this week")
                    .font(.custom("Satoshi Variable", size: 14).weight(.semibold))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                if let resetDate = activityStore.nextGenerationResetDate {
                    Text(exhausted
                         ? "Next 10 available \(activityStore.resetLabel(for: resetDate))"
                         : "Resets \(activityStore.resetLabel(for: resetDate))")
                        .font(.custom("Satoshi Variable", size: 12))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }

                Button {
                    showPaywall = true
                } label: {
                    Text("Upgrade for unlimited")
                        .font(.custom("Satoshi Variable", size: 12).weight(.medium))
                        .foregroundStyle(DS.ColorToken.primary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("\(activityStore.generationsThisWeek)/10")
                .font(.custom("Satoshi Variable", size: 16).weight(.bold))
                .foregroundStyle(exhausted ? DS.ColorToken.error : DS.ColorToken.warning)
        }
        .padding(DS.Spacing.space3)
        .background(exhausted ? DS.ColorToken.errorLight : DS.ColorToken.warningLight)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(exhausted ? DS.ColorToken.error.opacity(0.2) : DS.ColorToken.warning.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.bottom, DS.Spacing.space2)
    }

    // MARK: - Navigation Helpers

    private func stepButton(label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("Satoshi Variable", size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(DS.ColorToken.primary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    private func stepNavButtons(back: GenerateStep, next: GenerateStep) -> some View {
        VStack(spacing: DS.Spacing.space3) {
            stepButton(label: "Next", disabled: false) {
                goToStep(next)
            }

            Button { goToStep(back) } label: {
                Text("Back")
                    .font(.custom("Satoshi Variable", size: 14))
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .padding(.vertical, DS.Spacing.space3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.bottom, DS.Spacing.space4)
    }

    // MARK: - Generation

    @MainActor
    private func runGeneration() async {
        errorText = nil

        withAnimation(.easeInOut(duration: 0.25)) {
            step = .loading
        }

        let names: [String] = pantryStore.ingredients
            .filter { selectedIngredientIDs.contains($0.id) }
            .map { ingredient in
                if let amount = ingredient.amount, !amount.isEmpty {
                    return "\(ingredient.name) (\(amount))"
                }
                return ingredient.name
            }

        do {
            recipes = try await recipeGenerator.generateRecipes(
                for: names,
                options: options,
                recipeCount: session.isPremium ? 3 : 1
            )
            activityStore.logEvent(type: "recipe_generated")
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
    case dietType
    case dietaryRestrictions
    case cookingTime
    case calorieTarget
    case cuisineType
    case loading
    case results
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
            // Start at top (12 o'clock = -90°), full 360° circle
            let thumbAngleDeg = -90.0 + progress * 360.0
            let thumbAngle = Angle.degrees(thumbAngleDeg)
            let thumbPoint = CGPoint(
                x: center.x + radius * CGFloat(Foundation.cos(thumbAngle.radians)),
                y: center.y + radius * CGFloat(Foundation.sin(thumbAngle.radians))
            )

            ZStack {
                // Full track ring
                Circle()
                    .stroke(DS.ColorToken.borderDefault, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: radius * 2, height: radius * 2)

                // Filled arc from top
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DS.ColorToken.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: radius * 2, height: radius * 2)

                // Center label
                VStack(spacing: 2) {
                    Text(minutes >= maxMinutes ? "60+" : "\(minutes)")
                        .font(.custom("CalSans-Regular", size: 48))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                    Text("min")
                        .font(.custom("Satoshi Variable", size: 16).weight(.medium))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }

                // Thumb
                Circle()
                    .fill(DS.ColorToken.primary)
                    .frame(width: 28, height: 28)
                    .shadow(color: DS.ColorToken.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                    .position(thumbPoint)
            }
            .frame(width: size, height: size)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let vector = CGVector(dx: value.location.x - center.x, dy: value.location.y - center.y)
                        // atan2 gives angle from positive x-axis; shift so top (12 o'clock) = 0
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
                    .foregroundStyle(isSelected ? DS.ColorToken.accent : DS.ColorToken.textTertiary)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? DS.ColorToken.accent : DS.ColorToken.textSecondary)
                    .frame(width: 24)

                Text(label)
                    .font(.custom("Satoshi Variable", size: 16))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.space5)
            .frame(height: 48)
            .background(isSelected ? DS.ColorToken.accentLight : DS.ColorToken.bgSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(isSelected ? DS.ColorToken.accent.opacity(0.3) : DS.ColorToken.borderDefault, lineWidth: 1)
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
