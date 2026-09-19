import SwiftUI
import PhosphorSwift

/// One screen listing every item queued during a Photo Scan session. Reuses
/// `IngredientEntryFormContent` per item (via `BatchItemEditSheet`) exactly the way
/// `EditIngredientSheet` already does, rather than re-implementing the field components.
struct BatchScanReviewView: View {
    @Binding var items: [BatchScanItem]
    let onSaved: () -> Void
    let onRetakeRequested: (BatchScanItem) -> Void

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
            BatchItemEditSheet(existing: item) { updated in
                setItem(updated.id) { $0 = updated }
            }
        }
        .sheet(isPresented: $isAddingManually) {
            BatchItemEditSheet(existing: nil) { newItem in
                items.append(newItem)
            }
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

    /// User corrected the cost chip: that total is theirs. Store it as a `personal` cost on the
    /// item and stop re-resolving it; it gets upserted to `ingredient_price_history` on save.
    private func confirmCost(for item: BatchScanItem, newTotal: Double) {
        let (quantity, _) = item.costQuantityUnit
        let denom = quantity * Double(max(item.unitCount, 1))
        let unitPrice = denom > 0 ? newTotal / denom : newTotal
        setItem(item.id) {
            $0.cost = IngredientCost(
                unitPriceUsd: (unitPrice * 100).rounded() / 100,
                totalPriceUsd: newTotal,
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
                     ? "Dates and storage confirmed on all \(items.count) items."
                     : "Dates and amounts are estimates. These need a second look before saving.")
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
        VStack(spacing: 0) {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                Button {
                    editingItem = item
                } label: {
                    HStack(spacing: Sourdough.Spacing.rowInternals) {
                        thumbnail(for: item)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.ink)
                                .lineLimit(1)

                            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                                Text(item.category.icon + " " + item.category.title)
                                if let amountText = item.amountText, !amountText.isEmpty {
                                    Text(item.unitCount > 1 ? "· \(item.unitCount) × \(amountText)" : "· \(amountText)")
                                }
                                Text("· \(item.storageLocation.title)")
                            }
                            .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)
                            .lineLimit(1)

                            if item.suggestBarcodeRescan {
                                Text("Scan barcode instead?")
                                    .sourdoughTextStyle(.caption, color: Sourdough.Ramp.honeyDark)
                            } else if case .failed(let message) = item.status {
                                Text(message)
                                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.destructive)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)

                VStack(spacing: Sourdough.Spacing.insideChip) {
                    Button {
                        editingItem = item
                    } label: {
                        Ph.pencil.regular
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .frame(width: 38, height: 38)
                            .background(Sourdough.Colors.sunken)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        itemPendingRemoval = item
                    } label: {
                        Ph.trash.regular
                            .frame(width: 16, height: 16)
                            .foregroundStyle(Sourdough.Colors.onDestructive)
                            .frame(width: 38, height: 38)
                            .background(Sourdough.Colors.destructive)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Sourdough.Spacing.rowInternals)

            HStack {
                IngredientCostChip(cost: item.cost) { newTotal in
                    confirmCost(for: item, newTotal: newTotal)
                }
                Spacer()
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.insideChip)

            dateStrip(for: item)

            if item.isFlagged, !item.suggestBarcodeRescan {
                warningStrip(for: item)
            }
        }
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(item.isFlagged ? Sourdough.Ramp.honeyDark : Sourdough.Colors.hairline, lineWidth: item.isFlagged ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
    }

    private func dateStrip(for item: BatchScanItem) -> some View {
        let state = item.freshnessState
        return Button {
            setItem(item.id) { $0.warningDismissed = true }
        } label: {
            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                if let dot = state.dotColor {
                    Circle().fill(dot).frame(width: 5, height: 5)
                }
                Text(IngredientRowContent.chipText(state: state, days: item.daysUntilExpiration))
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                if let date = item.expirationDate {
                    Text(IngredientRowContent.formatExpiration(date))
                        .font(.system(size: 10.5, weight: .semibold))
                        .opacity(0.8)
                }
            }
            .foregroundStyle(state.style.label)
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(state.style.tint)
        }
        .buttonStyle(.plain)
    }

    private func warningStrip(for item: BatchScanItem) -> some View {
        let copy = warningCopy(for: item)
        return HStack(alignment: .top, spacing: Sourdough.Spacing.iconToLabel) {
            (Text(copy.title).fontWeight(.bold) + Text(" " + copy.body))
                .sourdoughTextStyle(.caption, color: Sourdough.Ramp.honey700)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Button(action: copy.fix) {
                    Text(copy.fixLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Sourdough.Ramp.onFilled)
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(Sourdough.Colors.action)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    setItem(item.id) { $0.warningDismissed = true }
                } label: {
                    Text("Keep")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Sourdough.Ramp.honey700)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .overlay(Capsule().stroke(Sourdough.Ramp.honey300, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Sourdough.Spacing.rowInternals)
        .background(Sourdough.Ramp.honey100)
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
            "Review",
            { editingItem = item }
        )
    }

    @ViewBuilder
    private func thumbnail(for item: BatchScanItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = item.thumbnail {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        Sourdough.Colors.sunken
                        Text(item.icon ?? item.category.icon).font(.system(size: 22))
                    }
                }
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))

            if item.isFlagged {
                Button {
                    onRetakeRequested(item)
                } label: {
                    Ph.camera.fill
                        .frame(width: 11, height: 11)
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Sourdough.Colors.ink)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Sourdough.Colors.card, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: 4)
            }
        }
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

    @State private var page: IngredientEntryPage = .main
    @State private var name: String
    @State private var icon: String
    @State private var category: Ingredient.Category
    @State private var location: Ingredient.StorageLocation
    @State private var expirationDate: Date?
    @State private var amountValue: Double
    @State private var amountUnit: UnitMeasurement
    @State private var unitCount: Int

    init(existing: BatchScanItem?, onSave: @escaping (BatchScanItem) -> Void) {
        self.existing = existing
        self.onSave = onSave

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
