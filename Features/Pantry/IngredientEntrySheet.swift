import SwiftUI
import PhosphorSwift

// MARK: - Unit Measurement

enum UnitMeasurement: String, CaseIterable, Identifiable {
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
    case pack
    case bunch
    case clove
    case head
    case stalk
    case sprig

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
        case .pack: return "pack"
        case .bunch: return "bunch"
        case .clove: return "clove"
        case .head: return "head"
        case .stalk: return "stalk"
        case .sprig: return "sprig"
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
        case .pack: return "Pack"
        case .bunch: return "Bunch"
        case .clove: return "Clove"
        case .head: return "Head"
        case .stalk: return "Stalk"
        case .sprig: return "Sprig"
        }
    }

    /// Display label for the Amount sub-sheet's unit picker — `.cups` reads singular ("cup") there
    /// even though the stored/parsed amount string keeps the plural `label` for backward
    /// compatibility with already-saved precise amounts.
    var chipLabel: String { self == .cups ? "cup" : label }

    /// All units offered in the Amount sub-sheet's unit dropdown, grouped weight → volume → count.
    static let pickerUnits: [UnitMeasurement] = [
        .g, .kg, .oz, .lb,
        .ml, .l, .cups, .tbsp, .tsp, .floz,
        .pieces, .pack, .bunch, .clove, .head, .stalk, .sprig,
    ]

    /// Stepper increment: 50 for g/ml, 0.5 for kg/L, 1 for pcs/pack/cup/tbsp (and any other unit).
    var stepSize: Double {
        switch self {
        case .g, .ml: return 50
        case .kg, .l: return 0.5
        default: return 1
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

// MARK: - Entry page

enum IngredientEntryPage: Equatable {
    case main
    case icon
    case amount
    case category
    case storage
    case expires
}

// MARK: - Sheet chrome

extension View {
    /// Bottom sheets in this flow fill the modal — content expands into the available height
    /// (via scrollable page bodies) rather than the sheet shrinking to fit content.
    func ingredientSheetChrome() -> some View {
        self
            .presentationDetents([.fraction(0.75)])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(Sourdough.Radius.sheet)
    }
}

// MARK: - Shared row chevron

private struct DetailChevron: View {
    var body: some View {
        Ph.caretRight.regular
            .frame(width: 18, height: 18)
            .foregroundStyle(Sourdough.Colors.interactiveBorder)
    }
}

// MARK: - Shared entry form content

/// Shared content for the Add/Edit/Scan-review flows — a single sheet container whose content
/// swaps in place between the main sheet, the icon picker, the amount editor, and the
/// category/storage/expires pickers, per `page`. Sub-page swaps resize the sheet rather than
/// pushing a new sheet, matching the design's "same container, same grabber" navigation model.
struct IngredientEntryFormContent: View {
    let title: String
    let saveLabel: String
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    let onMedicationDetected: () -> Void

    @Binding var page: IngredientEntryPage
    @Binding var name: String
    @Binding var icon: String
    @Binding var category: Ingredient.Category
    @Binding var location: Ingredient.StorageLocation
    /// The row's committed value — only written to when the Expires sub-sheet's Save is tapped.
    @Binding var expirationDate: Date?
    @Binding var amountValue: Double
    @Binding var amountUnit: UnitMeasurement
    /// How many of `amountValue`/`amountUnit`'s unit size the user has (e.g. 5 cans of 227g each).
    /// Only meaningful/editable in Exact mode — Rough mode's little/some/a lot buckets have no
    /// concrete per-unit size to multiply against.
    @Binding var unitCount: Int

    var onIconPicked: () -> Void
    var onCategoryPicked: () -> Void
    var onStoragePicked: () -> Void

    /// Shown above the name field on the main page when set — the "this looks off, fix it or
    /// keep it" prompt from a flagged batch-scan item. `nil` (the default) renders nothing, so
    /// `EditIngredientSheet` (which has no such concept) is unaffected.
    struct WarningBanner {
        let title: String
        let body: String
        let fixLabel: String
        let fix: () -> Void
        /// `nil` renders a single full-width `fix` button instead of a Fix/Keep as is pair — for
        /// warnings with no distinct second action.
        let keep: (() -> Void)?
    }
    var warningBanner: WarningBanner? = nil
    /// Small text link shown under the warning banner when set — batch-scan's "retake photo"
    /// escape hatch for a misidentified flagged item. `nil` renders nothing.
    var onRetakePhoto: (() -> Void)? = nil
    /// When set, renders a bordered trash icon button next to Save instead of Save alone.
    var onDelete: (() -> Void)? = nil

    var suggestionsProvider: ((String) async -> [IngredientSuggestion])? = nil

    @State private var iconSearchText = ""
    @State private var showingAllIcons = false
    @State private var nameSuggestions: [IngredientSuggestion] = []
    @State private var suggestionsTask: Task<Void, Never>?
    @State private var showMedicationAlert = false
    @FocusState private var isNameFieldFocused: Bool

    // Amount sub-sheet draft — only committed to the bound values above on "Save amount".
    @State private var draftValue: Double = 100
    @State private var draftValueText: String = "100"
    @State private var draftUnit: UnitMeasurement = .g
    @State private var draftUnitCount: Int = 1
    @State private var draftUnitCountText: String = "1"

    // Expires sub-sheet draft — only committed on "Save".
    @State private var draftExpiration: Date?

    private var amountLabel: String {
        let size = "\(QuantityConverter.formatQuantity(amountValue)) \(amountUnit.label)"
        return unitCount > 1 ? "\(unitCount) × \(size)" : size
    }

    private var expiresLabel: String {
        guard let expirationDate else { return "None" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: expirationDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 44, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.insideChip)

            switch page {
            case .main: mainPage
            case .icon: iconPage
            case .amount: amountPage
            case .category: categoryPage
            case .storage: storagePage
            case .expires: expiresPage
            }
        }
        .frame(maxHeight: .infinity)
        .background(Sourdough.Colors.canvas)
        .alert("Medication Detected", isPresented: $showMedicationAlert) {
            Button("OK") { onMedicationDetected() }
        } message: {
            Text("UseUp only tracks food. This item will be removed.")
        }
    }

    // MARK: Main

    private var mainPage: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .sourdoughTextStyle(.title1)
                    .foregroundStyle(Sourdough.Colors.ink)
                Spacer()
                Button("Cancel", action: onCancel)
                    .sourdoughTextStyle(.body, color: Sourdough.Colors.mutedInk)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.rowInternals)

            if let warningBanner {
                warningBannerView(warningBanner)
                    .padding(.horizontal, Sourdough.Spacing.screenMargin)
                    .padding(.bottom, Sourdough.Spacing.rowInternals)
            }

            ScrollView(showsIndicators: false) {
            VStack(spacing: Sourdough.Spacing.betweenBlocks) {
                nameField

                if let onRetakePhoto {
                    Button(action: onRetakePhoto) {
                        HStack(spacing: Sourdough.Spacing.iconToLabel) {
                            Ph.camera.regular.frame(width: 14, height: 14)
                            Text("Retake photo")
                                .sourdoughTextStyle(.subhead)
                        }
                        .foregroundStyle(Sourdough.Colors.actionInk)
                        .padding(.horizontal, Sourdough.Spacing.rowInternals)
                        .frame(height: 36)
                        .background(Sourdough.Colors.sunken)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                    Text("Details")
                        .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)
                        .padding(.leading, Sourdough.Spacing.iconToLabel)

                    VStack(spacing: 0) {
                        detailRow(label: "Category") {
                            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                                Text(category.icon).font(.system(size: 15))
                                Text(category.title)
                                    .sourdoughTextStyle(.body)
                                    .foregroundStyle(Sourdough.Colors.ink)
                            }
                            .padding(.horizontal, Sourdough.Spacing.rowInternals)
                            .padding(.vertical, Sourdough.Spacing.iconToLabel)
                            .background(Sourdough.Colors.sunken)
                            .clipShape(Capsule())
                        } action: { page = .category }

                        rowDivider

                        detailRow(label: "Amount") {
                            Text(amountLabel)
                                .sourdoughTextStyle(.rowTitle, color: Sourdough.Ramp.sage500)
                        } action: {
                            draftValue = amountValue
                            draftValueText = QuantityConverter.formatQuantity(amountValue)
                            draftUnit = amountUnit
                            draftUnitCount = unitCount
                            draftUnitCountText = "\(unitCount)"
                            page = .amount
                        }

                        rowDivider

                        detailRow(label: "Storage") {
                            HStack(spacing: Sourdough.Spacing.iconToLabel - 1) {
                                storageIcon(for: location)
                                    .frame(width: 16, height: 16)
                                Text(location.title)
                                    .sourdoughTextStyle(.rowTitle, color: Sourdough.Ramp.sage500)
                            }
                            .foregroundStyle(Sourdough.Ramp.sage500)
                        } action: { page = .storage }

                        rowDivider

                        detailRow(label: "Expires") {
                            Text(expiresLabel)
                                .sourdoughTextStyle(.rowTitle, color: Sourdough.Ramp.sage500)
                        } action: {
                            draftExpiration = expirationDate
                            page = .expires
                        }
                    }
                    .background(Sourdough.Colors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                            .stroke(Sourdough.Colors.hairline, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.insideChip)
            }
            .frame(maxHeight: .infinity)
            .scrollDismissesKeyboard(.immediately)

            if let onDelete {
                HStack(spacing: Sourdough.Spacing.insideChip) {
                    Button(action: onDelete) {
                        Ph.trash.regular
                            .frame(width: 17, height: 17)
                            .foregroundStyle(Sourdough.Colors.action)
                            .frame(width: 54, height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                                    .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        if MedicationDetector.isMedication(name) {
                            showMedicationAlert = true
                        } else {
                            onSave()
                        }
                    } label: {
                        Text(saveLabel)
                            .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.onAction)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(canSave ? Sourdough.Ramp.sage500 : Sourdough.Ramp.sage500.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                            .sourdoughElevation(.lifted)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.betweenBlocks - Sourdough.Spacing.insideChip)
                .padding(.bottom, Sourdough.Spacing.betweenBlocks - Sourdough.Spacing.insideChip)
            } else {
                saveButton(label: saveLabel, enabled: canSave) {
                    if MedicationDetector.isMedication(name) {
                        showMedicationAlert = true
                    } else {
                        onSave()
                    }
                }
                .padding(.top, Sourdough.Spacing.betweenBlocks - Sourdough.Spacing.insideChip)
            }
        }
    }

    private func warningBannerView(_ banner: WarningBanner) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            (Text(banner.title).fontWeight(.bold) + Text(" " + banner.body))
                .sourdoughTextStyle(.caption, color: Sourdough.Ramp.honey700)

            if let keep = banner.keep {
                HStack(spacing: Sourdough.Spacing.insideChip) {
                    Button(action: banner.fix) {
                        Text(banner.fixLabel)
                            .sourdoughTextStyle(.subhead, color: Sourdough.Ramp.onFilled)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Sourdough.Ramp.terracotta500)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: keep) {
                        Text("Keep as is")
                            .sourdoughTextStyle(.subhead, color: Sourdough.Ramp.honey700)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                                    .stroke(Sourdough.Ramp.honey300, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: banner.fix) {
                    Text(banner.fixLabel)
                        .sourdoughTextStyle(.subhead, color: Sourdough.Ramp.onFilled)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Sourdough.Ramp.terracotta500)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Sourdough.Spacing.rowInternals)
        .background(Sourdough.Ramp.honey100)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Sourdough.Colors.sunken)
            .frame(height: 1)
            .padding(.leading, Sourdough.Spacing.rowInternals + Sourdough.Spacing.iconToLabel)
    }

    private func detailRow<Value: View>(label: String, @ViewBuilder value: () -> Value, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                Text(label)
                    .sourdoughTextStyle(.body)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                value()
                DetailChevron()
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals + Sourdough.Spacing.iconToLabel)
            .padding(.vertical, Sourdough.Spacing.rowInternals)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                Button(action: { page = .icon }) {
                    ZStack {
                        Circle()
                            .fill(Sourdough.Colors.card)
                            .overlay(Circle().stroke(Sourdough.Colors.hairline, lineWidth: 1))
                            .frame(width: 48, height: 48)
                        Text(icon)
                            .font(.system(size: 24))
                    }
                    .overlay(alignment: .bottomTrailing) {
                        ZStack {
                            Circle()
                                .fill(Sourdough.Ramp.sage500)
                                .overlay(Circle().stroke(Sourdough.Colors.sunken, lineWidth: 2))
                                .frame(width: 20, height: 20)
                            Ph.pencil.fill
                                .frame(width: 10, height: 10)
                                .foregroundStyle(Sourdough.Colors.onAction)
                        }
                        .offset(x: -2, y: -2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change icon")

                TextField("e.g. Chicken breast", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .sourdoughTextStyle(.rowTitle)
                    .foregroundStyle(Sourdough.Colors.ink)
                    .focused($isNameFieldFocused)
                    .onChange(of: name) { _, newValue in
                        guard let suggestionsProvider else { return }
                        suggestionsTask?.cancel()
                        suggestionsTask = Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            let results = await suggestionsProvider(newValue)
                            guard !Task.isCancelled else { return }
                            nameSuggestions = results
                        }
                    }
                    .onChange(of: isNameFieldFocused) { _, focused in
                        if !focused { nameSuggestions = [] }
                    }
            }
            .padding(.leading, Sourdough.Spacing.insideChip)
            .padding(.trailing, Sourdough.Spacing.insideChip)
            .padding(.vertical, Sourdough.Spacing.insideChip)
            .background(Sourdough.Colors.sunken)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card + 2, style: .continuous))

            if isNameFieldFocused, !nameSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(nameSuggestions) { suggestion in
                        Button {
                            name = suggestion.name
                            nameSuggestions = []
                            isNameFieldFocused = false
                        } label: {
                            HStack(spacing: Sourdough.Spacing.insideChip) {
                                Text(suggestion.category.icon).font(.system(size: 16))
                                Text(suggestion.name.capitalized)
                                    .sourdoughTextStyle(.body)
                                    .foregroundStyle(Sourdough.Colors.ink)
                                Spacer()
                            }
                            .padding(.horizontal, Sourdough.Spacing.rowInternals)
                            .frame(height: 40)
                        }
                        .buttonStyle(.plain)
                        if suggestion.id != nameSuggestions.last?.id { Divider() }
                    }
                }
                .background(Sourdough.Colors.card)
                .overlay(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous).stroke(Sourdough.Colors.hairline, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous))
                .padding(.top, Sourdough.Spacing.insideChip)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func storageIcon(for loc: Ingredient.StorageLocation) -> Image {
        switch loc {
        case .fridge: return Ph.doorOpen.regular
        case .freezer: return Ph.snowflake.regular
        case .pantry: return Ph.archive.regular
        }
    }

    private func saveButton(label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.onAction)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(enabled ? Sourdough.Ramp.sage500 : Sourdough.Ramp.sage500.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                .sourdoughElevation(.lifted)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.bottom, Sourdough.Spacing.betweenBlocks - Sourdough.Spacing.insideChip)
    }

    // MARK: Sub-sheet header

    private func subHeader(_ title: String, trailingLabel: String, trailingAction: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .sourdoughTextStyle(.title1)
                .foregroundStyle(Sourdough.Colors.ink)
            Spacer()
            Button(trailingLabel, action: trailingAction)
                .sourdoughTextStyle(.body, color: Sourdough.Colors.mutedInk)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
    }

    // MARK: Icon page

    private var iconSuggestions: [String] {
        IngredientDefaults.suggestedIcons(forName: name, category: category)
    }

    private var searchResults: [String] {
        IngredientDefaults.searchIcons(query: iconSearchText)
    }

    private var iconPage: some View {
        VStack(spacing: 0) {
            subHeader("Choose an icon", trailingLabel: "Done") { page = .main }

            ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks - Sourdough.Spacing.insideChip) {
                HStack(spacing: Sourdough.Spacing.rowInternals) {
                    Ph.magnifyingGlass.regular
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Sourdough.Colors.mutedInk)
                    TextField("Search icons", text: $iconSearchText)
                        .sourdoughTextStyle(.body)
                        .foregroundStyle(Sourdough.Colors.ink)
                }
                .padding(.horizontal, Sourdough.Spacing.rowInternals + Sourdough.Spacing.iconToLabel)
                .padding(.vertical, Sourdough.Spacing.rowInternals)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile + 2, style: .continuous))

                if iconSearchText.isEmpty {
                    VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                        Text("Suggested for \u{201C}\(name.isEmpty ? "this item" : name)\u{201D}")
                            .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)
                            .padding(.leading, Sourdough.Spacing.iconToLabel)

                        HStack(spacing: Sourdough.Spacing.rowInternals) {
                            ForEach(iconSuggestions, id: \.self) { emoji in
                                iconTile(emoji, size: 64, fontSize: 28)
                            }
                        }
                    }

                    if showingAllIcons {
                        allIconsGrid
                    } else {
                        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
                            HStack {
                                Text(category.title)
                                    .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)
                                Spacer()
                                Button("All icons") { showingAllIcons = true }
                                    .sourdoughTextStyle(.subhead)
                                    .foregroundStyle(Sourdough.Colors.mutedInk)
                                    .buttonStyle(.plain)
                            }
                            .padding(.leading, Sourdough.Spacing.iconToLabel)

                            iconGrid(IngredientDefaults.iconLibrary[category] ?? IngredientDefaults.allIcons)
                        }
                    }
                } else {
                    iconGrid(searchResults)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.betweenBlocks + Sourdough.Spacing.insideChip)
            }
            .frame(maxHeight: .infinity)
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private var allIconsGrid: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("All icons")
                .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)
                .padding(.leading, Sourdough.Spacing.iconToLabel)
            iconGrid(IngredientDefaults.allIcons)
        }
    }

    private func iconGrid(_ emojis: [String]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Sourdough.Spacing.rowInternals), count: 5), spacing: Sourdough.Spacing.rowInternals) {
            ForEach(emojis, id: \.self) { emoji in
                iconTile(emoji, size: nil, fontSize: 26)
            }
        }
    }

    private func iconTile(_ emoji: String, size: CGFloat?, fontSize: CGFloat) -> some View {
        let isSelected = icon == emoji
        return Button {
            icon = emoji
            onIconPicked()
            page = .main
        } label: {
            Text(emoji)
                .font(.system(size: fontSize))
                .frame(width: size, height: size ?? 60)
                .frame(maxWidth: size == nil ? .infinity : nil)
                .background(isSelected ? Sourdough.Colors.card : Sourdough.Colors.sunken)
                .overlay(
                    RoundedRectangle(cornerRadius: Sourdough.Radius.tile + 2, style: .continuous)
                        .stroke(isSelected ? Sourdough.Ramp.sage500 : Color.clear, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile + 2, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(emoji) icon")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Amount page

    private var amountPage: some View {
        VStack(spacing: 0) {
            subHeader("Amount", trailingLabel: "Cancel") { page = .main }

            ScrollView(showsIndicators: false) {
            VStack(spacing: Sourdough.Spacing.betweenBlocks + Sourdough.Spacing.insideChip) {
                amountField
                unitField
                quantityField
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.betweenBlocks)
            .padding(.bottom, Sourdough.Spacing.betweenBlocks)
            }
            .frame(maxHeight: .infinity)

            saveButton(label: "Save amount") {
                amountValue = draftValue
                amountUnit = draftUnit
                unitCount = draftUnitCount
                page = .main
            }
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Amount")
                .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)
                .padding(.leading, Sourdough.Spacing.iconToLabel)

            HStack {
                stepperButton(icon: Ph.minus.bold, background: Sourdough.Colors.sunken, glyphColor: Sourdough.Colors.ink, label: "Decrease amount") {
                    let next = (draftValue - draftUnit.stepSize).rounded(toPlaces: 2)
                    draftValue = max(draftUnit.stepSize, next)
                    draftValueText = QuantityConverter.formatQuantity(draftValue)
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: Sourdough.Spacing.iconToLabel + 2) {
                    TextField("0", text: $draftValueText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 70)
                        .sourdoughTextStyle(.display)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .onChange(of: draftValueText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber || $0 == "." }
                            if filtered != newValue { draftValueText = filtered }
                            if let parsed = Double(filtered) { draftValue = parsed }
                        }
                    Text(draftUnit.chipLabel)
                        .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.mutedInk)
                }
                Spacer()
                stepperButton(icon: Ph.plus.bold, background: Sourdough.Ramp.sage500, glyphColor: Sourdough.Colors.onAction, label: "Increase amount") {
                    draftValue = (draftValue + draftUnit.stepSize).rounded(toPlaces: 2)
                    draftValueText = QuantityConverter.formatQuantity(draftValue)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals + Sourdough.Spacing.iconToLabel)
            .padding(.vertical, Sourdough.Spacing.rowInternals)
            .background(Sourdough.Colors.card)
            .overlay(RoundedRectangle(cornerRadius: Sourdough.Radius.card + 2, style: .continuous).stroke(Sourdough.Colors.hairline, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card + 2, style: .continuous))
        }
    }

    private var unitField: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Unit")
                .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)
                .padding(.leading, Sourdough.Spacing.iconToLabel)

            Menu {
                ForEach(UnitMeasurement.pickerUnits) { unit in
                    Button {
                        draftUnit = unit
                    } label: {
                        HStack {
                            Text(unit.chipLabel)
                            if draftUnit == unit {
                                Ph.check.regular.frame(width: 16, height: 16)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Sourdough.Spacing.iconToLabel) {
                    Text(draftUnit.chipLabel)
                        .sourdoughTextStyle(.body, color: Sourdough.Colors.ink)
                    Spacer()
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

    private var quantityField: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text("Quantity")
                .sourdoughTextStyle(.sectionHead, color: Sourdough.Colors.mutedInk)
                .padding(.leading, Sourdough.Spacing.iconToLabel)

            HStack {
                stepperButton(icon: Ph.minus.bold, background: Sourdough.Colors.sunken, glyphColor: Sourdough.Colors.ink, label: "Decrease quantity") {
                    draftUnitCount = max(1, draftUnitCount - 1)
                    draftUnitCountText = "\(draftUnitCount)"
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: Sourdough.Spacing.iconToLabel) {
                    TextField("1", text: $draftUnitCountText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(minWidth: 50)
                        .sourdoughTextStyle(.display)
                        .foregroundStyle(Sourdough.Colors.ink)
                        .onChange(of: draftUnitCountText) { _, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue { draftUnitCountText = filtered }
                            if let parsed = Int(filtered), parsed > 0 { draftUnitCount = parsed }
                        }
                    Text(draftUnitCount == 1 ? "unit" : "units")
                        .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.mutedInk)
                }
                Spacer()
                stepperButton(icon: Ph.plus.bold, background: Sourdough.Ramp.sage500, glyphColor: Sourdough.Colors.onAction, label: "Increase quantity") {
                    draftUnitCount += 1
                    draftUnitCountText = "\(draftUnitCount)"
                }
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals + Sourdough.Spacing.iconToLabel)
            .padding(.vertical, Sourdough.Spacing.rowInternals)
            .background(Sourdough.Colors.card)
            .overlay(RoundedRectangle(cornerRadius: Sourdough.Radius.card + 2, style: .continuous).stroke(Sourdough.Colors.hairline, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card + 2, style: .continuous))
        }
    }

    private func stepperButton(icon: Image, background: Color, glyphColor: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon
                .frame(width: 20, height: 20)
                .foregroundStyle(glyphColor)
                .frame(width: 50, height: 50)
                .background(background)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: Category page

    private var categoryPage: some View {
        VStack(spacing: 0) {
            subHeader("Choose a category", trailingLabel: "Done") { page = .main }

            ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Sourdough.Spacing.insideChip), GridItem(.flexible(), spacing: Sourdough.Spacing.insideChip)], spacing: Sourdough.Spacing.insideChip) {
                ForEach(Ingredient.Category.allCases) { cat in
                    Button {
                        category = cat
                        onCategoryPicked()
                        page = .main
                    } label: {
                        HStack(spacing: Sourdough.Spacing.iconToLabel) {
                            Text(cat.icon).font(.system(size: 20))
                            Text(cat.title)
                                .sourdoughTextStyle(.body, color: category == cat ? Sourdough.Colors.onAction : Sourdough.Colors.ink)
                            Spacer()
                        }
                        .padding(.horizontal, Sourdough.Spacing.rowInternals)
                        .frame(height: 52)
                        .background(category == cat ? Sourdough.Ramp.sage500 : Sourdough.Colors.sunken)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile + 2, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(category == cat ? .isSelected : [])
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.betweenBlocks + Sourdough.Spacing.insideChip)
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: Storage page

    private var storagePage: some View {
        VStack(spacing: 0) {
            subHeader("Choose storage", trailingLabel: "Done") { page = .main }

            ScrollView(showsIndicators: false) {
            VStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(Ingredient.StorageLocation.allCases) { loc in
                    Button {
                        location = loc
                        onStoragePicked()
                        page = .main
                    } label: {
                        HStack(spacing: Sourdough.Spacing.rowInternals) {
                            storageIcon(for: loc)
                                .frame(width: 20, height: 20)
                            Text(loc.title)
                                .sourdoughTextStyle(.rowTitle, color: location == loc ? Sourdough.Colors.onAction : Sourdough.Colors.ink)
                            Spacer()
                            if location == loc {
                                Ph.check.bold.frame(width: 18, height: 18)
                            }
                        }
                        .foregroundStyle(location == loc ? Sourdough.Colors.onAction : Sourdough.Colors.ink)
                        .padding(.horizontal, Sourdough.Spacing.rowInternals + Sourdough.Spacing.iconToLabel)
                        .frame(height: 56)
                        .background(location == loc ? Sourdough.Ramp.sage500 : Sourdough.Colors.sunken)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile + 2, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(location == loc ? .isSelected : [])
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.betweenBlocks + Sourdough.Spacing.insideChip)
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: Expires page

    private var expiresPage: some View {
        VStack(spacing: 0) {
            subHeader("Expires", trailingLabel: "Cancel") { page = .main }

            ScrollView(showsIndicators: false) {
            VStack(spacing: Sourdough.Spacing.betweenBlocks) {
                DatePicker(
                    "",
                    selection: Binding(get: { draftExpiration ?? Date() }, set: { draftExpiration = $0 }),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Sourdough.Ramp.sage500)
                .labelsHidden()
                .background(Sourdough.Colors.card)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card + 2, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Sourdough.Radius.card + 2, style: .continuous).stroke(Sourdough.Colors.hairline, lineWidth: 1))

                Button("No expiration") { draftExpiration = nil }
                    .sourdoughTextStyle(.subhead)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.betweenBlocks - Sourdough.Spacing.insideChip)
            }
            .frame(maxHeight: .infinity)

            saveButton(label: "Save") {
                expirationDate = draftExpiration
                page = .main
            }
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

// MARK: - Edit Ingredient Sheet

struct EditIngredientSheet: View {
    @Environment(\.dismiss) private var dismiss

    let ingredient: Ingredient
    let onSave: (String, String?, Int, Ingredient.QuantityEstimate?, Ingredient.QuantitySource?, Ingredient.Category, Ingredient.StorageLocation, Date?, String?) -> Void
    let onMedicationDetected: () -> Void

    @State private var page: IngredientEntryPage = .main
    @State private var name: String
    @State private var icon: String
    @State private var category: Ingredient.Category
    @State private var location: Ingredient.StorageLocation
    @State private var expirationDate: Date?

    @State private var amountValue: Double
    @State private var amountUnit: UnitMeasurement
    @State private var unitCount: Int

    init(
        ingredient: Ingredient,
        onSave: @escaping (String, String?, Int, Ingredient.QuantityEstimate?, Ingredient.QuantitySource?, Ingredient.Category, Ingredient.StorageLocation, Date?, String?) -> Void,
        onMedicationDetected: @escaping () -> Void
    ) {
        self.ingredient = ingredient
        self.onSave = onSave
        self.onMedicationDetected = onMedicationDetected
        _name = State(initialValue: ingredient.name)
        _icon = State(initialValue: ingredient.icon ?? ingredient.category.icon)
        _category = State(initialValue: ingredient.category)
        _location = State(initialValue: ingredient.location)
        _expirationDate = State(initialValue: ingredient.expirationDate)
        _unitCount = State(initialValue: ingredient.unitCount)

        if let amount = ingredient.amount, !amount.isEmpty {
            let parsed = UnitMeasurement.parse(from: amount)
            _amountValue = State(initialValue: Double(parsed.value) ?? 1)
            _amountUnit = State(initialValue: parsed.unit)
        } else {
            // No prior exact amount (e.g. only ever roughly estimated) — seed a neutral
            // generic default rather than presuming grams; editing always captures an
            // exact value now, so this is the "upgrade to exact" starting point.
            _amountValue = State(initialValue: 1)
            _amountUnit = State(initialValue: .pieces)
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var formattedAmount: String {
        "\(QuantityConverter.formatQuantity(amountValue)) \(amountUnit.label)"
    }

    /// Preserves the ingredient's original `quantitySource` (e.g. `.barcode`) when re-saving
    /// without actually changing the amount — only recomputes it when the value differs.
    private var resolvedQuantitySource: Ingredient.QuantitySource {
        let unchanged = formattedAmount == ingredient.amount
        return unchanged ? (ingredient.quantitySource ?? .manualPrecise) : .manualPrecise
    }

    var body: some View {
        IngredientEntryFormContent(
            title: "Edit Ingredient",
            saveLabel: "Save Changes",
            canSave: canSave,
            onCancel: { dismiss() },
            onSave: {
                onSave(name, formattedAmount, unitCount, nil, resolvedQuantitySource, category, location, expirationDate, icon)
                dismiss()
            },
            onMedicationDetected: {
                onMedicationDetected()
                dismiss()
            },
            page: $page,
            name: $name,
            icon: $icon,
            category: $category,
            location: $location,
            expirationDate: $expirationDate,
            amountValue: $amountValue,
            amountUnit: $amountUnit,
            unitCount: $unitCount,
            onIconPicked: {},
            onCategoryPicked: {},
            onStoragePicked: {}
        )
        .ingredientSheetChrome()
    }
}
