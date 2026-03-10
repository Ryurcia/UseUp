import SwiftUI

struct PantryView: View {
    @EnvironmentObject private var pantryStore: PantryStore
    @EnvironmentObject private var session: AppSession
    @Binding var requestAddSheet: Bool

    init(requestAddSheet: Binding<Bool> = .constant(false)) {
        _requestAddSheet = requestAddSheet
    }

    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var selectedCategories: Set<PantryCategory> = []
    @State private var selectedStorageFilters: Set<StorageFilter> = []
    @State private var filterExpiringSoon = false
    @State private var showingAddSheet = false
    @State private var showingFilterSheet = false
    @State private var showingSettings = false
    @State private var ingredientPendingDelete: Ingredient?
    @State private var ingredientBeingEdited: Ingredient?
    @State private var ingredientBeingUsed: Ingredient?
    @State private var expandedIngredientID: UUID?
    private var hasActiveFilters: Bool {
        !selectedStorageFilters.isEmpty || !selectedCategories.isEmpty || filterExpiringSoon
    }
    private var greetingName: String {
        if let displayName = session.currentUserDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            return displayName
        }

        return "there"
    }

    private var filteredIngredients: [Ingredient] {
        pantryStore.ingredients
            .filter { ingredient in
                let trimmedSearch = debouncedSearch.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchesSearch = trimmedSearch.isEmpty || ingredient.name.localizedCaseInsensitiveContains(trimmedSearch)
                let matchesCategory = selectedCategories.isEmpty || selectedCategories.contains { $0.matches(ingredient: ingredient) }
                let matchesStorage = selectedStorageFilters.isEmpty || selectedStorageFilters.contains { $0.matches(ingredient: ingredient) }
                let matchesExpiring = !filterExpiringSoon || (ingredient.daysUntilExpiration ?? Int.max) <= 5
                return matchesSearch && matchesCategory && matchesStorage && matchesExpiring
            }
            .sorted { $0.loggedAt > $1.loggedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            VStack(alignment: .leading, spacing: DS.Spacing.space4) {
                searchBar

                HStack {
                    Text("Your Pantry")
                        .appTextStyle(.heading3)
                        .foregroundStyle(DS.ColorToken.textSecondary)

                    Spacer()

                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: hasActiveFilters
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(
                                hasActiveFilters
                                    ? DS.ColorToken.primary
                                    : DS.ColorToken.textSecondary
                            )
                    }
                    .buttonStyle(.plain)
                }

                if filteredIngredients.isEmpty {
                    Spacer(minLength: DS.Spacing.space8)
                    VStack(spacing: DS.Spacing.space3) {
                        Image(systemName: "face.dashed")
                            .font(.system(size: 48))
                            .foregroundStyle(DS.ColorToken.textTertiary)
                        Text("Looks like you haven't logged anything")
                            .appTextStyle(.bodySM)
                            .foregroundStyle(DS.ColorToken.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: DS.Spacing.space2) {
                            ForEach(filteredIngredients) { item in
                                ExpandableIngredientRow(
                                    item: item,
                                    isExpanded: expandedIngredientID == item.id,
                                    onTap: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            expandedIngredientID = expandedIngredientID == item.id ? nil : item.id
                                        }
                                    },
                                    onUse: {
                                        expandedIngredientID = nil
                                        ingredientBeingUsed = item
                                    },
                                    onEdit: {
                                        expandedIngredientID = nil
                                        ingredientBeingEdited = item
                                    },
                                    onDelete: {
                                        expandedIngredientID = nil
                                        ingredientPendingDelete = item
                                    }
                                )
                            }
                        }
                        .padding(.bottom, DS.Spacing.space24)
                        .background(DS.ColorToken.bgPrimary)
                    }
                    .scrollContentBackground(.hidden)
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
            }
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(DS.ColorToken.bgPrimary)
        .overlay {
            if showingAddSheet || showingFilterSheet || showingSettings || ingredientBeingEdited != nil || ingredientBeingUsed != nil {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.2), value: showingAddSheet)
                    .animation(.easeInOut(duration: 0.2), value: showingFilterSheet)
                    .animation(.easeInOut(duration: 0.2), value: showingSettings)
                    .animation(.easeInOut(duration: 0.2), value: ingredientBeingEdited != nil)
                    .animation(.easeInOut(duration: 0.2), value: ingredientBeingUsed != nil)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAddSheet) {
            AddIngredientSheet { name, amount, category, location, expirationDate in
                withAnimation {
                    pantryStore.addIngredient(name: name, amount: amount, category: category, location: location, expirationDate: expirationDate)
                }
            }
        }
        .onChange(of: requestAddSheet) { _, request in
            if request {
                requestAddSheet = false
                showingAddSheet = true
            }
        }
        .sheet(item: $ingredientBeingEdited) { ingredient in
            EditIngredientSheet(ingredient: ingredient) { name, amount, category, location, expirationDate in
                withAnimation {
                    pantryStore.updateIngredient(
                        id: ingredient.id,
                        name: name,
                        amount: amount,
                        category: category,
                        location: location,
                        expirationDate: expirationDate
                    )
                }
            }
        }
        .sheet(item: $ingredientBeingUsed) { ingredient in
            UseIngredientSheet(ingredient: ingredient) { newAmount in
                withAnimation {
                    pantryStore.useIngredient(id: ingredient.id, newAmount: newAmount)
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Delete ingredient?", isPresented: isShowingDeleteAlert, presenting: ingredientPendingDelete) { ingredient in
            Button("Cancel", role: .cancel) {
                ingredientPendingDelete = nil
            }
            Button("Delete", role: .destructive) {
                withAnimation {
                    pantryStore.deleteIngredient(id: ingredient.id)
                }
                ingredientPendingDelete = nil
            }
        } message: { ingredient in
            Text("This will remove \(ingredient.name.capitalized) from your pantry.")
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(
                selectedStorageFilters: $selectedStorageFilters,
                selectedCategories: $selectedCategories,
                filterExpiringSoon: $filterExpiringSoon
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        .task {
            await pantryStore.fetchIngredients()
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

    private var headerView: some View {
        VStack(spacing: DS.Spacing.space3) {
            HStack {
                Text("Today is \(Date.now, format: .dateTime.month(.wide).day())")
                    .font(.custom("Satoshi Variable", size: 22).weight(.semibold))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(DS.ColorToken.accent)
                }
                .buttonStyle(.plain)
            }

            Text("Hey \(greetingName)!")
                .font(.custom("CalSans-Regular", size: 36))
                .kerning(0)
                .foregroundStyle(DS.ColorToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !expiringSoonItems.isEmpty {
                (Text("You have ")
                    + Text("\(expiringSoonItems.count) items expiring soon")
                        .font(.custom("Satoshi Variable", size: 18).weight(.bold))
                        .foregroundColor(DS.ColorToken.primary))
                    .font(.custom("Satoshi Variable", size: 18))
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                expiringCard
            }
        }
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.top, DS.Spacing.space2)
        .padding(.bottom, DS.Spacing.space4)
    }

    private var expiringSoonItems: [Ingredient] {
        pantryStore.ingredients
            .filter { $0.expirationDate != nil && ($0.daysUntilExpiration ?? Int.max) <= 5 }
            .sorted { ($0.daysUntilExpiration ?? Int.max) < ($1.daysUntilExpiration ?? Int.max) }
    }

    private var expiringCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space3) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.primary)
                Text("USE THESE UP")
                    .font(.custom("Satoshi Variable", size: 13).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(DS.ColorToken.primary)
            }

            if expiringSoonItems.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.space2) {
                        expiringItemChips
                    }
                }
            } else {
                HStack(spacing: DS.Spacing.space2) {
                    expiringItemChips
                }
            }
        }
        .padding(DS.Spacing.space4)
        .background(DS.ColorToken.bgTertiary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xxl, style: .continuous)
                .stroke(DS.ColorToken.primary.opacity(0.25), lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private var expiringItemChips: some View {
        ForEach(expiringSoonItems) { item in
            HStack(spacing: 0) {
                Text(item.name.capitalized)
                    .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                if let days = item.daysUntilExpiration {
                    Text(" · \(expirationLabel(days))")
                        .font(.custom("Satoshi Variable", size: 14).weight(.semibold))
                }
            }
            .foregroundStyle(DS.ColorToken.textPrimary)
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.vertical, DS.Spacing.space3)
            .background(DS.ColorToken.bgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        }
    }

    private func expirationLabel(_ days: Int) -> String {
        if days <= 0 { return "0d" }
        return "\(days)d"
    }

    private var searchBar: some View {
        HStack(spacing: DS.Spacing.space2) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DS.ColorToken.textTertiary)

            TextField("Search your pantry", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .appTextStyle(.body)
                .foregroundStyle(DS.ColorToken.textPrimary)
        }
        .padding(.horizontal, DS.Spacing.space3)
        .frame(height: 48)
        .background(DS.ColorToken.bgSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
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

// MARK: - Extracted Equatable Ingredient Row

private struct IngredientRowContent: View, Equatable {
    let item: Ingredient

    private static let expirationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yyyy"
        return formatter
    }()

    static func == (lhs: IngredientRowContent, rhs: IngredientRowContent) -> Bool {
        lhs.item == rhs.item
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space2) {
            HStack(spacing: DS.Spacing.space2) {
                pillLabel(
                    text: item.location.title,
                    foreground: .white,
                    background: DS.ColorToken.warning
                )

                pillLabel(
                    text: item.category.title,
                    foreground: DS.ColorToken.accent,
                    background: DS.ColorToken.accentLight
                )

                if let days = item.daysUntilExpiration, days <= 5 {
                    let (label, fg, bg) = expirationStyle(days: days)
                    pillLabel(text: label, foreground: fg, background: bg)
                } else if let expirationDate = item.expirationDate {
                    Text("exp. on \(Self.expirationDateFormatter.string(from: expirationDate))")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.space3) {
                Text(item.name.capitalized)
                    .font(.custom("Satoshi Variable", size: 20).weight(.semibold))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let amount = item.amount, !amount.isEmpty {
                    Text(amount)
                        .appTextStyle(.body)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.space5)
        .padding(.vertical, DS.Spacing.space3)
    }

    private func pillLabel(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .appTextStyle(.overline)
            .foregroundStyle(foreground)
            .padding(.horizontal, DS.Spacing.space2)
            .padding(.vertical, DS.Spacing.space1)
            .background(background)
            .clipShape(Capsule())
    }

    private func expirationStyle(days: Int) -> (String, Color, Color) {
        if days < 0 {
            return ("Expired", DS.ColorToken.error, DS.ColorToken.errorLight)
        } else if days == 0 {
            return ("Expires today", DS.ColorToken.error, DS.ColorToken.errorLight)
        } else if days == 1 {
            return ("Expires tomorrow", DS.ColorToken.error, DS.ColorToken.errorLight)
        } else if days <= 3 {
            return ("Expires in \(days) days", DS.ColorToken.warning, DS.ColorToken.warningLight)
        } else if days <= 5 {
            return ("Expires in \(days) days", DS.ColorToken.error, DS.ColorToken.errorLight)
        } else {
            return ("Expires in \(days) days", DS.ColorToken.textSecondary, DS.ColorToken.bgSecondary)
        }
    }
}

private enum PantryCategory: String, CaseIterable, Identifiable {
    case proteins
    case vegetables
    case carbs
    case dairy
    case fruits
    case condiments
    case other

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

private struct ExpandableIngredientRow: View {
    let item: Ingredient
    let isExpanded: Bool
    let onTap: () -> Void
    let onUse: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            IngredientRowContent(item: item)

            if isExpanded {
                HStack(spacing: DS.Spacing.space3) {
                    actionButton(label: "Use", icon: "minus.circle", color: DS.ColorToken.accent, action: onUse)
                    actionButton(label: "Edit", icon: "pencil", color: DS.ColorToken.info, action: onEdit)
                    actionButton(label: "Delete", icon: "trash", color: DS.ColorToken.error, action: onDelete)
                }
                .padding(.horizontal, DS.Spacing.space4)
                .padding(.top, DS.Spacing.space3)
                .padding(.bottom, DS.Spacing.space4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(DS.ColorToken.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(isExpanded ? DS.ColorToken.primary.opacity(0.3) : DS.ColorToken.borderDefault, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private func actionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.space1) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.custom("Satoshi Variable", size: 14).weight(.semibold))
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private enum StorageFilter: CaseIterable, Identifiable {
    case fridge
    case freezer
    case pantry

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

#Preview("Pantry") {
    PreviewContainer {
        NavigationStack {
            PantryView()
        }
    }
}

private struct AddIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amountValue = ""
    @State private var unit: UnitMeasurement = .none
    @State private var category: Ingredient.Category = .other
    @State private var location: Ingredient.StorageLocation = .fridge
    @State private var hasExpiration = false
    @State private var expirationDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()

    let onSave: (String, String?, Ingredient.Category, Ingredient.StorageLocation, Date?) -> Void

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
            canSave: canSave,
            saveLabel: "Add Ingredient",
            onCancel: { dismiss() },
            onSave: {
                onSave(name, formattedAmount, category, location, hasExpiration ? expirationDate : nil)
                dismiss()
            }
        )
    }
}

private struct EditIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss

    let ingredient: Ingredient
    let onSave: (String, String?, Ingredient.Category, Ingredient.StorageLocation, Date?) -> Void

    @State private var name: String
    @State private var amountValue: String
    @State private var unit: UnitMeasurement
    @State private var category: Ingredient.Category
    @State private var location: Ingredient.StorageLocation
    @State private var hasExpiration: Bool
    @State private var expirationDate: Date

    init(
        ingredient: Ingredient,
        onSave: @escaping (String, String?, Ingredient.Category, Ingredient.StorageLocation, Date?) -> Void
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
            canSave: canSave,
            saveLabel: "Save Changes",
            onCancel: { dismiss() },
            onSave: {
                onSave(name, formattedAmount, category, location, hasExpiration ? expirationDate : nil)
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
    let canSave: Bool
    let saveLabel: String
    let onCancel: () -> Void
    let onSave: () -> Void

    private func storageIcon(for loc: Ingredient.StorageLocation) -> String {
        switch loc {
        case .fridge: return "refrigerator"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle + header
            Capsule()
                .fill(DS.ColorToken.borderDefault)
                .frame(width: 36, height: 5)
                .padding(.top, DS.Spacing.space3)
                .padding(.bottom, DS.Spacing.space4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.space6) {
                    // Title + cancel
                    HStack {
                        Text(title)
                            .appTextStyle(.heading2)
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        Spacer()

                        Button("Cancel", action: onCancel)
                            .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                            .foregroundStyle(DS.ColorToken.textSecondary)
                            .buttonStyle(.plain)
                    }

                    // Name field
                    VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                        Text("Ingredient Name")
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        TextField("e.g. Chicken breast", text: $name)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .appTextStyle(.body)
                            .foregroundStyle(DS.ColorToken.textPrimary)
                            .padding(.horizontal, DS.Spacing.space3)
                            .frame(height: 48)
                            .background(DS.ColorToken.bgSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                    .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                    }

                    // Amount field
                    VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                        Text("Amount")
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        HStack(spacing: DS.Spacing.space2) {
                            TextField("e.g. 500", text: $amountValue)
                                .keyboardType(.decimalPad)
                                .onChange(of: amountValue) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                    if filtered != newValue { amountValue = filtered }
                                }
                                .appTextStyle(.body)
                                .foregroundStyle(DS.ColorToken.textPrimary)
                                .padding(.horizontal, DS.Spacing.space3)
                                .frame(height: 48)
                                .background(DS.ColorToken.bgSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                        .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))

                            Menu {
                                ForEach(UnitMeasurement.allCases) { u in
                                    Button {
                                        unit = u
                                    } label: {
                                        HStack {
                                            Text(u.displayName)
                                            if unit == u {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: DS.Spacing.space1) {
                                    Text(unit.label.isEmpty ? "Unit" : unit.label)
                                        .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                                        .foregroundStyle(
                                            unit == .none
                                                ? DS.ColorToken.textTertiary
                                                : DS.ColorToken.textPrimary
                                        )
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(DS.ColorToken.textTertiary)
                                }
                                .padding(.horizontal, DS.Spacing.space3)
                                .frame(height: 48)
                                .background(DS.ColorToken.bgSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                        .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                            }
                        }
                    }

                    // Category
                    VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                        Text("Category")
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: DS.Spacing.space2),
                            GridItem(.flexible(), spacing: DS.Spacing.space2),
                            GridItem(.flexible(), spacing: DS.Spacing.space2)
                        ], spacing: DS.Spacing.space2) {
                            ForEach(Ingredient.Category.allCases) { cat in
                                Button {
                                    category = cat
                                } label: {
                                    HStack(spacing: DS.Spacing.space1) {
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 12))
                                        Text(cat.title)
                                            .font(.custom("Satoshi Variable", size: 13).weight(.medium))
                                    }
                                    .foregroundStyle(
                                        category == cat ? .white : DS.ColorToken.textSecondary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(
                                        category == cat
                                            ? DS.ColorToken.primary
                                            : DS.ColorToken.bgSecondary
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                            .stroke(
                                                category == cat
                                                    ? Color.clear
                                                    : DS.ColorToken.borderDefault,
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Storage location
                    VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                        Text("Storage Location")
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        HStack(spacing: DS.Spacing.space2) {
                            ForEach(Ingredient.StorageLocation.allCases) { loc in
                                Button {
                                    location = loc
                                } label: {
                                    HStack(spacing: DS.Spacing.space2) {
                                        Image(systemName: storageIcon(for: loc))
                                            .font(.system(size: 14))
                                        Text(loc.title)
                                            .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                                    }
                                    .foregroundStyle(
                                        location == loc ? .white : DS.ColorToken.textSecondary
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(
                                        location == loc
                                            ? DS.ColorToken.primary
                                            : DS.ColorToken.bgSecondary
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                            .stroke(
                                                location == loc
                                                    ? Color.clear
                                                    : DS.ColorToken.borderDefault,
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Expiration
                    VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                        Text("Expiration Date")
                            .appTextStyle(.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        HStack {
                            Text("Has expiration date")
                                .font(.custom("Satoshi Variable", size: 15).weight(.regular))
                                .foregroundStyle(DS.ColorToken.textPrimary)

                            Spacer()

                            Toggle("", isOn: $hasExpiration)
                                .labelsHidden()
                                .tint(DS.ColorToken.primary)
                        }
                        .padding(.horizontal, DS.Spacing.space3)
                        .frame(height: 48)
                        .background(DS.ColorToken.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))

                        if hasExpiration {
                            DatePicker(
                                "Expires on",
                                selection: $expirationDate,
                                displayedComponents: .date
                            )
                            .font(.custom("Satoshi Variable", size: 15).weight(.regular))
                            .tint(DS.ColorToken.primary)
                            .padding(.horizontal, DS.Spacing.space3)
                            .frame(height: 48)
                            .background(DS.ColorToken.bgSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                    .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.space5)
            }

            // Save button
            Button(action: onSave) {
                Text(saveLabel)
                    .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSave ? DS.ColorToken.primary : DS.ColorToken.primary.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space4)
        }
        .background(DS.ColorToken.bgPrimary)
    }
}

// MARK: - Use Ingredient Sheet

private struct UseIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss

    let ingredient: Ingredient
    let onUse: (String?) -> Void

    @State private var usageText = ""
    @State private var useAll = false

    private let parsed: (value: String, unit: UnitMeasurement)

    private var isParseable: Bool {
        !parsed.value.isEmpty && Double(parsed.value) != nil
    }

    private var currentValue: Double? {
        Double(parsed.value)
    }

    private var canConfirm: Bool {
        if useAll { return true }
        let trimmed = usageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isParseable {
            guard let usage = Double(trimmed), usage > 0 else { return false }
            return true
        }
        return !trimmed.isEmpty
    }

    init(ingredient: Ingredient, onUse: @escaping (String?) -> Void) {
        self.ingredient = ingredient
        self.onUse = onUse
        self.parsed = UnitMeasurement.parse(from: ingredient.amount)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(DS.ColorToken.borderDefault)
                .frame(width: 36, height: 5)
                .padding(.top, DS.Spacing.space3)
                .padding(.bottom, DS.Spacing.space4)

            VStack(spacing: DS.Spacing.space6) {
                // Header
                HStack {
                    Text("Use Ingredient")
                        .appTextStyle(.heading2)
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    Spacer()

                    Button("Cancel") { dismiss() }
                        .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .buttonStyle(.plain)
                }

                // Ingredient info
                VStack(alignment: .leading, spacing: DS.Spacing.space1) {
                    Text(ingredient.name.capitalized)
                        .appTextStyle(.heading3)
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    if let amount = ingredient.amount, !amount.isEmpty {
                        Text("Current: \(amount)")
                            .appTextStyle(.bodySM)
                            .foregroundStyle(DS.ColorToken.textSecondary)
                    } else {
                        Text("No amount set")
                            .appTextStyle(.bodySM)
                            .foregroundStyle(DS.ColorToken.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isParseable {
                    parseableModeContent
                } else {
                    unparseableModeContent
                }
            }
            .padding(.horizontal, DS.Spacing.space5)

            Spacer()

            // Confirm button
            Button(action: confirm) {
                Text("Confirm")
                    .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canConfirm ? DS.ColorToken.accent : DS.ColorToken.accent.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canConfirm)
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space4)
        }
        .background(DS.ColorToken.bgPrimary)
    }

    // MARK: - Mode A: Parseable amount

    private var parseableModeContent: some View {
        VStack(spacing: DS.Spacing.space4) {
            VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                Text("How much are you using?")
                    .appTextStyle(.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)

                HStack(spacing: DS.Spacing.space2) {
                    TextField("e.g. 100", text: $usageText)
                        .keyboardType(.decimalPad)
                        .onChange(of: usageText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber || $0 == "." }
                            if filtered != newValue { usageText = filtered }
                        }
                        .disabled(useAll)
                        .appTextStyle(.body)
                        .foregroundStyle(useAll ? DS.ColorToken.textTertiary : DS.ColorToken.textPrimary)
                        .padding(.horizontal, DS.Spacing.space3)
                        .frame(height: 48)
                        .background(DS.ColorToken.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))

                    if parsed.unit != .none {
                        Text(parsed.unit.label)
                            .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                            .foregroundStyle(DS.ColorToken.textSecondary)
                            .padding(.horizontal, DS.Spacing.space3)
                            .frame(height: 48)
                            .background(DS.ColorToken.bgSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                    .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                    }
                }
            }

            HStack {
                Text("Use All")
                    .font(.custom("Satoshi Variable", size: 15).weight(.regular))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()

                Toggle("", isOn: $useAll)
                    .labelsHidden()
                    .tint(DS.ColorToken.accent)
            }
            .padding(.horizontal, DS.Spacing.space3)
            .frame(height: 48)
            .background(DS.ColorToken.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                    .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
        }
    }

    // MARK: - Mode B: Unparseable / nil amount

    private var unparseableModeContent: some View {
        VStack(spacing: DS.Spacing.space4) {
            HStack {
                Text("Use All")
                    .font(.custom("Satoshi Variable", size: 15).weight(.regular))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()

                Toggle("", isOn: $useAll)
                    .labelsHidden()
                    .tint(DS.ColorToken.accent)
            }
            .padding(.horizontal, DS.Spacing.space3)
            .frame(height: 48)
            .background(DS.ColorToken.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                    .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))

            if !useAll {
                VStack(alignment: .leading, spacing: DS.Spacing.space2) {
                    Text("How much are you using?")
                        .appTextStyle(.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)

                    TextField("e.g. 2 cups", text: $usageText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .appTextStyle(.body)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .padding(.horizontal, DS.Spacing.space3)
                        .frame(height: 48)
                        .background(DS.ColorToken.bgSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                }
            }
        }
    }

    // MARK: - Confirm logic

    private func confirm() {
        if useAll {
            onUse(nil)
        } else if isParseable, let current = currentValue, let usage = Double(usageText) {
            let remaining = current - usage
            if remaining <= 0 {
                onUse(nil)
            } else {
                let formatted = remaining.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(remaining)) : String(remaining)
                let newAmount = parsed.unit == .none ? formatted : "\(formatted) \(parsed.unit.label)"
                onUse(newAmount)
            }
        } else {
            // Unparseable current amount — try to parse the usage input and subtract
            let usageParsed = UnitMeasurement.parse(from: usageText)
            if let usageVal = Double(usageParsed.value),
               let amount = ingredient.amount,
               let currentParsed = Double(UnitMeasurement.parse(from: amount).value) {
                let remaining = currentParsed - usageVal
                if remaining <= 0 {
                    onUse(nil)
                } else {
                    let currentUnit = UnitMeasurement.parse(from: amount).unit
                    let formatted = remaining.truncatingRemainder(dividingBy: 1) == 0
                        ? String(Int(remaining)) : String(remaining)
                    let newAmount = currentUnit == .none ? formatted : "\(formatted) \(currentUnit.label)"
                    onUse(newAmount)
                }
            } else {
                // Can't subtract, just remove
                onUse(nil)
            }
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

        for u in UnitMeasurement.allCases where u != .none {
            if amount.hasSuffix(" \(u.label)") {
                let value = String(amount.dropLast(u.label.count + 1))
                return (value, u)
            }
        }

        return (amount, .none)
    }
}

private struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStorageFilters: Set<StorageFilter>
    @Binding var selectedCategories: Set<PantryCategory>
    @Binding var filterExpiringSoon: Bool

    private var hasActiveFilters: Bool {
        !selectedStorageFilters.isEmpty || !selectedCategories.isEmpty || filterExpiringSoon
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
                                filterExpiringSoon = false
                            } label: {
                                Text("Reset")
                                    .font(.custom("Satoshi Variable", size: 14).weight(.medium))
                                    .foregroundStyle(DS.ColorToken.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Expires Soon
                    filterRow(
                        icon: "clock.badge.exclamationmark",
                        label: "Expires Soon",
                        isSelected: filterExpiringSoon
                    ) {
                        filterExpiringSoon.toggle()
                    }

                    // Storage section
                    VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                        Text("Storage")
                            .appTextStyle(.heading3)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        VStack(spacing: DS.Spacing.space2) {
                            ForEach(StorageFilter.allCases) { filter in
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

                    // Category section
                    VStack(alignment: .leading, spacing: DS.Spacing.space3) {
                        Text("Category")
                            .appTextStyle(.heading3)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        VStack(spacing: DS.Spacing.space2) {
                            ForEach(PantryCategory.allCases) { category in
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

            Button {
                dismiss()
            } label: {
                Text("Apply Filters")
                    .font(.custom("Satoshi Variable", size: 16).weight(.semibold))
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
                            ? DS.ColorToken.primary
                            : DS.ColorToken.textTertiary
                    )

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        isSelected
                            ? DS.ColorToken.primary
                            : DS.ColorToken.textSecondary
                    )
                    .frame(width: 24)

                Text(label)
                    .font(.custom("Satoshi Variable", size: 16).weight(.medium))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.space5)
            .frame(height: 48)
            .background(
                isSelected
                    ? DS.ColorToken.primaryLight
                    : DS.ColorToken.bgSecondary
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(
                        isSelected
                            ? DS.ColorToken.primary.opacity(0.3)
                            : DS.ColorToken.borderDefault,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
