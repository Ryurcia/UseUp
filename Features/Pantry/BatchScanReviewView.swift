import SwiftUI
import PhosphorSwift

/// One screen listing every item queued during a Photo Scan session. Reuses
/// `IngredientEntryFormContent` per item (via `BatchItemEditSheet`) exactly the way
/// `EditIngredientSheet` already does, rather than re-implementing the field components.
struct BatchScanReviewView: View {
    @Binding var items: [BatchScanItem]
    let onSaved: () -> Void
    let onRetakeRequested: (BatchScanItem) -> Void
    let onAddMoreRequested: () -> Void

    @EnvironmentObject private var pantryStore: PantryStore
    @State private var editingItem: BatchScanItem?
    @State private var isAddingManually = false
    @State private var isSaving = false
    @State private var itemPendingRemoval: BatchScanItem?
    @State private var onlyFlagged = false

    private let costEstimator: IngredientCostEstimating = TestingMode.isEnabled ? MockIngredientCostEstimator() : SupabaseIngredientCostEstimator()

    private var flaggedCount: Int { items.filter(\.isFlagged).count }

    /// Flagged items surfaced first, then soonest-expiring within each group — visible without
    /// hunting, without forcing a modal. Filtered to flagged-only when `onlyFlagged` is toggled.
    private var sortedItems: [BatchScanItem] {
        let ordered = items.enumerated().sorted { lhs, rhs in
            if lhs.element.isFlagged != rhs.element.isFlagged {
                return lhs.element.isFlagged
            }
            let lhsDays = lhs.element.daysUntilExpiration ?? Int.max
            let rhsDays = rhs.element.daysUntilExpiration ?? Int.max
            if lhsDays != rhsDays { return lhsDays < rhsDays }
            return lhs.offset < rhs.offset
        }.map(\.element)
        return onlyFlagged ? ordered.filter(\.isFlagged) : ordered
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: Sourdough.Spacing.insideChip) {
                ForEach(sortedItems) { item in
                    row(for: item)
                }

                if flaggedCount == 0 && !onlyFlagged && !items.isEmpty {
                    allClearBanner
                }

                HStack(spacing: Sourdough.Spacing.insideChip) {
                    Button {
                        isAddingManually = true
                    } label: {
                        HStack(spacing: Sourdough.Spacing.iconToLabel) {
                            Ph.plus.bold.frame(width: 16, height: 16)
                            Text("Add Item Manually")
                        }
                        .sourdoughTextStyle(.rowTitle, color: Sourdough.Ramp.sage500)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Sourdough.Colors.sunken)
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile + 2, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: onAddMoreRequested) {
                        Ph.camera.regular
                            .frame(width: 20, height: 20)
                            .foregroundStyle(Sourdough.Ramp.sage500)
                            .frame(width: 52, height: 52)
                            .background(Sourdough.Colors.sunken)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile + 2, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, 140)
        }
        .background(Sourdough.Colors.canvas)
        .task(id: pendingCostItemIDs) { await resolvePendingCosts() }
        .navigationTitle("Review \(items.count) Item\(items.count == 1 ? "" : "s")")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            reviewBanner
        }
        .safeAreaInset(edge: .bottom) {
            saveAllButton
        }
        .sheet(item: $editingItem) { item in
            BatchItemEditSheet(
                existing: item,
                onSave: { updated in setItem(updated.id) { $0 = updated } },
                onMedicationDetected: { items.removeAll { $0.id == item.id } },
                onDeleteRequested: { itemPendingRemoval = item },
                onRetakeRequested: { onRetakeRequested(item) },
                warningBanner: item.isFlagged ? sheetWarningBanner(for: item) : nil
            )
        }
        .sheet(isPresented: $isAddingManually) {
            BatchItemEditSheet(
                existing: nil,
                onSave: { items.append($0) },
                onMedicationDetected: {},
                onDeleteRequested: {},
                onRetakeRequested: {},
                warningBanner: nil
            )
        }
        .alert("Remove item?", isPresented: Binding(
            get: { itemPendingRemoval != nil },
            set: { if !$0 { itemPendingRemoval = nil } }
        ), presenting: itemPendingRemoval) { item in
            Button("Cancel", role: .cancel) { itemPendingRemoval = nil }
            Button("Remove", role: .destructive) {
                items.removeAll { $0.id == item.id }
                itemPendingRemoval = nil
            }
        } message: { item in
            Text("This will remove \(item.name.capitalized) from this batch.")
        }
    }

    /// Mutates the item with the given id in place, no-op if it's no longer present — the single
    /// write path for every row-level action below.
    private func setItem(_ id: UUID, _ mutate: (inout BatchScanItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[index])
    }

    // MARK: - Cost resolution

    private var pendingCostItemIDs: [UUID] {
        items.filter { $0.cost == nil && !$0.costConfirmed && !$0.name.isEmpty }.map(\.id)
    }

    /// Resolves a cost estimate for every item that doesn't have one yet, concurrently. A failure
    /// leaves `cost` nil — the chip shows a muted placeholder, never an error.
    private func resolvePendingCosts() async {
        let targets = items.filter { $0.cost == nil && !$0.costConfirmed && !$0.name.isEmpty }
        guard !targets.isEmpty else { return }

        await withTaskGroup(of: (UUID, IngredientCost?).self) { group in
            for item in targets {
                let (quantity, unit) = item.costQuantityUnit
                group.addTask {
                    let cost = try? await costEstimator.resolveCost(
                        ingredientName: item.name,
                        quantity: quantity,
                        unit: unit,
                        unitCount: item.unitCount,
                        barcode: item.barcode
                    )
                    return (item.id, cost)
                }
            }
            for await (id, cost) in group {
                if let cost { setItem(id) { $0.cost = cost } }
            }
        }
    }

    /// User corrected the per-unit cost chip: that price is theirs. Store it as a `personal` cost
    /// on the item and stop re-resolving it; it gets upserted to `ingredient_price_history` on save.
    private func confirmUnitCost(for item: BatchScanItem, newUnitPrice: Double) {
        let (quantity, _) = item.costQuantityUnit
        let denom = quantity * Double(max(item.unitCount, 1))
        setItem(item.id) {
            $0.cost = IngredientCost(
                unitPriceUsd: (newUnitPrice * 100).rounded() / 100,
                totalPriceUsd: ((newUnitPrice * denom) * 100).rounded() / 100,
                source: .personal,
                conversionApplied: false,
                confidence: 1
            )
            $0.costConfirmed = true
        }
    }

    // MARK: - Review banner

    private var reviewBanner: some View {
        Button {
            guard flaggedCount > 0 else { return }
            onlyFlagged.toggle()
        } label: {
            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                ZStack {
                    Circle().fill(flaggedCount == 0 ? Sourdough.Ramp.sage500 : Sourdough.Ramp.honey500)
                    if flaggedCount == 0 {
                        Ph.check.bold.frame(width: 10, height: 10).foregroundStyle(Sourdough.Ramp.onFilled)
                    } else {
                        Text("\(flaggedCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Sourdough.Ramp.onFilled)
                    }
                }
                .frame(width: 20, height: 20)

                Text(flaggedCount == 0
                     ? "All checked. Tap a card again to change anything."
                     : "Tap a card to check or fix it.")
                    .sourdoughTextStyle(.caption, color: flaggedCount == 0 ? Sourdough.Colors.fresh.label : Sourdough.Colors.soon.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                if flaggedCount > 0 {
                    Text(onlyFlagged ? "Show all" : "Show these")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Sourdough.Colors.soon.label)
                }
            }
            .padding(Sourdough.Spacing.rowInternals)
            .background(flaggedCount == 0 ? Sourdough.Colors.fresh.tint : Sourdough.Colors.soon.tint)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.insideChip)
        .padding(.bottom, Sourdough.Spacing.insideChip)
        .background(Sourdough.Colors.canvas)
    }

    private var allClearBanner: some View {
        HStack(alignment: .top, spacing: Sourdough.Spacing.rowInternals) {
            ZStack {
                Circle().fill(Sourdough.Ramp.sage500)
                Ph.check.bold.frame(width: 12, height: 12).foregroundStyle(Sourdough.Ramp.onFilled)
            }
            .frame(width: 26, height: 26)

            Text("All \(items.count) checked. Dates and storage look right — save them to your pantry.")
                .sourdoughTextStyle(.caption, color: Sourdough.Colors.fresh.label)
        }
        .padding(Sourdough.Spacing.rowInternals)
        .background(Sourdough.Colors.fresh.tint)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous)
                .strokeBorder(Sourdough.Ramp.sage300, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.tile, style: .continuous))
    }

    // MARK: - Row

    private func row(for item: BatchScanItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            card(for: item)
            IngredientCostChip(cost: item.cost) { newUnitPrice in
                confirmUnitCost(for: item, newUnitPrice: newUnitPrice)
            }
            .padding(.horizontal, Sourdough.Spacing.insideChip)
        }
    }

    private func card(for item: BatchScanItem) -> some View {
        let wasFlagged = item.needsAttention || item.hasStorageMismatch
        let resolved = wasFlagged && item.warningDismissed
        let state = item.freshnessState
        return Button {
            editingItem = item
        } label: {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                ZStack {
                    categoryTint(for: item.category)
                    Text(item.icon ?? item.category.icon).font(.system(size: 25))
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.ink)
                        .lineLimit(1)

                    Text(rowMeta(for: item))
                        .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)
                        .lineLimit(1)

                    if state.dotColor == nil {
                        if item.suggestBarcodeRescan {
                            Text("Scan barcode instead?")
                                .sourdoughTextStyle(.caption, color: Sourdough.Ramp.honeyDark)
                        } else if case .failed(let message) = item.status {
                            Text(message)
                                .sourdoughTextStyle(.caption, color: Sourdough.Colors.destructive)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let dot = state.dotColor {
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 6) {
                            Circle().fill(dot).frame(width: 5, height: 5)
                            Text(IngredientRowContent.chipText(state: state, days: item.daysUntilExpiration))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(state.style.label)
                        }
                        if let date = item.expirationDate {
                            Text(IngredientRowContent.formatExpiration(date))
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(Sourdough.Colors.mutedInk)
                        }
                    }
                }

                if resolved {
                    statusBadge(background: Sourdough.Ramp.sage500) {
                        Ph.check.bold.frame(width: 13, height: 13)
                    }
                }
            }
            .padding(.vertical, 11)
            .padding(.leading, 11)
            .padding(.trailing, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(
                    item.isFlagged ? Sourdough.Ramp.terracotta500 : resolved ? Sourdough.Ramp.sage200 : Sourdough.Colors.hairline,
                    lineWidth: item.isFlagged ? 2 : 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
    }

    /// `"qty · storage"`, matching the caption line the old row used.
    private func rowMeta(for item: BatchScanItem) -> String {
        var parts: [String] = []
        if let amountText = item.amountText, !amountText.isEmpty {
            parts.append(item.unitCount > 1 ? "\(item.unitCount) × \(amountText)" : amountText)
        }
        parts.append(item.storageLocation.title)
        return parts.joined(separator: " · ")
    }

    private func categoryTint(for category: Ingredient.Category) -> Color {
        switch category {
        case .produce, .vegetables, .fruits: return Sourdough.Ramp.sage100
        case .proteins, .seafood: return Sourdough.Ramp.terracotta100
        case .dairy: return Sourdough.Colors.canvas
        case .carbs, .condiments, .other: return Sourdough.Ramp.honey100
        }
    }

    @ViewBuilder
    private func statusBadge<Content: View>(background: Color, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Circle().fill(background)
            content().foregroundStyle(Sourdough.Ramp.onFilled)
        }
        .frame(width: 26, height: 26)
    }

    /// A single, honest warning per flagged item. Storage mismatch is a real, independently
    /// derived signal with an exact fix; everything else falls back to the existing confidence
    /// signal, since Gemini's confidence is one scalar and doesn't say *which* attribute is
    /// uncertain — the copy below is a best-guess heuristic, not a distinct detector.
    private func warningCopy(for item: BatchScanItem) -> (title: String, body: String, fixLabel: String, fix: () -> Void) {
        if item.hasStorageMismatch {
            let correct = IngredientDefaults.defaultStorage(for: item.category)
            return (
                "Storage looks off.",
                "\(item.category.title) usually keeps in the \(correct.title.lowercased()).",
                correct.title,
                { setItem(item.id) { $0.storageLocation = correct; $0.warningDismissed = true } }
            )
        }
        if item.freshnessState != .fresh {
            return (
                "Estimated date.",
                "This is a category guess — worth confirming before you rely on it.",
                "Confirm",
                { setItem(item.id) { $0.warningDismissed = true } }
            )
        }
        return (
            "Worth a second look.",
            "Confidence was low on this one — check the name, category, and amount.",
            "Looks good",
            { editingItem = item }
        )
    }

    /// Adapts `warningCopy(for:)` for use inside the edit sheet itself. Storage-mismatch and
    /// estimated-date warnings have a real, distinct fix, so they keep the Fix/Keep as is pair.
    /// The generic low-confidence fallback has no automated fix — its `fix` normally opens the
    /// edit sheet (`editingItem = item`), which is meaningless when already inside it — so it
    /// collapses to a single "Looks good" button that just acknowledges the warning.
    private func sheetWarningBanner(for item: BatchScanItem) -> IngredientEntryFormContent.WarningBanner {
        let copy = warningCopy(for: item)
        guard item.hasStorageMismatch || item.freshnessState != .fresh else {
            return IngredientEntryFormContent.WarningBanner(
                title: copy.title,
                body: copy.body,
                fixLabel: "Looks good",
                fix: { setItem(item.id) { $0.warningDismissed = true } },
                keep: nil
            )
        }
        return IngredientEntryFormContent.WarningBanner(
            title: copy.title,
            body: copy.body,
            fixLabel: copy.fixLabel,
            fix: copy.fix,
            keep: { setItem(item.id) { $0.warningDismissed = true } }
        )
    }

    private var saveAllButton: some View {
        VStack(spacing: Sourdough.Spacing.insideChip) {
            Button {
                guard !isSaving else { return }
                isSaving = true
                Task {
                    let toSave = items
                    await pantryStore.addIngredients(toSave)
                    for item in toSave where item.costConfirmed {
                        if let unitPrice = item.cost?.unitPriceUsd {
                            await pantryStore.upsertConfirmedPrice(
                                ingredientName: item.name,
                                unitPrice: unitPrice,
                                unit: item.costQuantityUnit.unit,
                                barcode: item.barcode
                            )
                        }
                    }
                    isSaving = false
                    onSaved()
                }
            } label: {
                HStack(spacing: Sourdough.Spacing.iconToLabel) {
                    if isSaving { ProgressView().tint(Sourdough.Colors.onAction) }
                    Text(isSaving ? "Saving…" : (flaggedCount == 0 ? "Save all \(items.count) to pantry" : "Save all \(items.count) · \(flaggedCount) unchecked"))
                }
                .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.onAction)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(flaggedCount == 0 ? Sourdough.Colors.action : Sourdough.Ramp.terracotta400)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(items.isEmpty || isSaving)
            .opacity(items.isEmpty ? 0.4 : 1)

            if !items.isEmpty {
                Text(flaggedCount == 0
                     ? "Items land in your pantry and start counting down."
                     : "You can save now — unchecked estimates stay editable in the pantry.")
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.insideChip)
        .padding(.bottom, Sourdough.Spacing.rowInternals)
        .background(Sourdough.Colors.canvas)
    }
}

// MARK: - Batch item edit sheet

/// Mirrors `EditIngredientSheet`'s structure, operating on a `BatchScanItem` draft instead of a
/// persisted `Ingredient`. `existing == nil` is the "Add Item Manually" case (a blank draft seeded
/// with `IngredientDefaults`, same defaults a fresh manual entry would have gotten).
private struct BatchItemEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: BatchScanItem?
    let onSave: (BatchScanItem) -> Void
    let onMedicationDetected: () -> Void
    let onDeleteRequested: () -> Void
    let onRetakeRequested: () -> Void
    let warningBanner: IngredientEntryFormContent.WarningBanner?

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
        existing: BatchScanItem?,
        onSave: @escaping (BatchScanItem) -> Void,
        onMedicationDetected: @escaping () -> Void,
        onDeleteRequested: @escaping () -> Void,
        onRetakeRequested: @escaping () -> Void,
        warningBanner: IngredientEntryFormContent.WarningBanner?
    ) {
        self.existing = existing
        self.onSave = onSave
        self.onMedicationDetected = onMedicationDetected
        self.onDeleteRequested = onDeleteRequested
        self.onRetakeRequested = onRetakeRequested
        self.warningBanner = warningBanner

        if let existing {
            _name = State(initialValue: existing.name)
            _icon = State(initialValue: existing.icon ?? existing.category.icon)
            _category = State(initialValue: existing.category)
            _location = State(initialValue: existing.storageLocation)
            _expirationDate = State(initialValue: existing.expirationDate)
            _unitCount = State(initialValue: existing.unitCount)
        } else {
            let seed = IngredientDefaults.defaults(forName: "")
            _name = State(initialValue: "")
            _icon = State(initialValue: seed.icon)
            _category = State(initialValue: seed.category)
            _location = State(initialValue: seed.storage)
            _expirationDate = State(initialValue: Calendar.current.date(byAdding: .day, value: seed.shelfLifeDays, to: Date()))
            _unitCount = State(initialValue: 1)
        }

        if let amount = existing?.amountText, !amount.isEmpty {
            let parsed = UnitMeasurement.parse(from: amount)
            _amountValue = State(initialValue: Double(parsed.value) ?? 1)
            _amountUnit = State(initialValue: parsed.unit)
        } else {
            // No prior exact amount — seed a neutral generic default rather than presuming
            // grams; editing always captures an exact value now.
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

    var body: some View {
        IngredientEntryFormContent(
            title: existing == nil ? "Add Item" : "Edit Item",
            saveLabel: existing == nil ? "Add Item" : "Save Changes",
            canSave: canSave,
            onCancel: { dismiss() },
            onSave: {
                var result = existing ?? BatchScanItem(captureToken: UUID(), name: name, storageLocation: location, status: .identified)
                // Name/amount changes the ingredient's identity or per-unit size, so the estimate
                // needs a fresh fetch. Quantity alone doesn't — the per-unit price is unaffected by
                // how many the user has, so it's rescaled locally below instead of re-resolved.
                let sizeInputsChanged = existing == nil
                    || existing?.name != name
                    || existing?.amountText != formattedAmount
                let unitCountChanged = existing?.unitCount != unitCount
                result.name = name
                result.icon = icon
                result.category = category
                result.amountText = formattedAmount
                result.unitCount = unitCount
                result.storageLocation = location
                result.expirationDate = expirationDate
                result.status = .identified
                result.suggestBarcodeRescan = false
                result.warningDismissed = true
                if sizeInputsChanged {
                    result.cost = nil
                    result.costConfirmed = false
                } else if unitCountChanged, let unitPrice = result.cost?.unitPriceUsd {
                    let (quantity, _) = result.costQuantityUnit
                    let newTotal = unitPrice * quantity * Double(max(unitCount, 1))
                    result.cost?.totalPriceUsd = (newTotal * 100).rounded() / 100
                }
                onSave(result)
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
            onStoragePicked: {},
            warningBanner: warningBanner.map { banner in
                IngredientEntryFormContent.WarningBanner(
                    title: banner.title,
                    body: banner.body,
                    fixLabel: banner.fixLabel,
                    fix: { banner.fix(); dismiss() },
                    keep: banner.keep.map { keepFn in { keepFn(); dismiss() } }
                )
            },
            onRetakePhoto: (existing?.isFlagged == true) ? { onRetakeRequested(); dismiss() } : nil,
            onDelete: existing != nil ? { onDeleteRequested(); dismiss() } : nil
        )
        .ingredientSheetChrome()
    }
}
