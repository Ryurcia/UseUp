import SwiftUI
import PhosphorSwift

// MARK: - Step 1: Save to Collection vs Just Save

/// Shown wherever a not-yet-saved recipe's Save/bookmark button is tapped. Replaces the old
/// single-tap `SaveCategoryPicker` (breakfast/lunch/dinner/snack) with a choice between the new
/// Collections flow and today's plain save.
struct SaveChoiceSheet: View {
    var onSaveToCollection: () -> Void
    var onJustSave: () -> Void

    var body: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)

            Text("Save Recipe")
                .sourdoughTextStyle(.title2, color: Sourdough.Colors.ink)
                .padding(.bottom, Sourdough.Spacing.insideChip)

            Button(action: onSaveToCollection) {
                HStack(spacing: Sourdough.Spacing.rowInternals) {
                    Ph.folders.regular
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save to Collection")
                            .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.ink)
                        Text("Organize it into a collection")
                            .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)
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
            .padding(.horizontal, Sourdough.Spacing.screenMargin)

            Button(action: onJustSave) {
                Text("Just Save")
                    .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.onAction)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Sourdough.Colors.action)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)

            Spacer()
        }
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Step 2: Pick (or create) Collections

/// Multi-select list of the user's collections, plus an inline "create new" affordance —
/// confirming applies the recipe to every selected collection at once.
struct CollectionPickerSheet: View {
    let recipe: Recipe
    /// When true, collections the recipe is already in are hidden (not shown pre-selected) — the
    /// "add it somewhere new" flow (Cookbook long-press). Default keeps the show-all / pre-select
    /// behaviour the save flows rely on.
    var excludeExisting: Bool = false
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCollectionIDs: Set<UUID> = []
    @State private var showNewCollectionField = false
    @State private var newCollectionName = ""
    @State private var isCreating = false
    @State private var isSaving = false
    @State private var saveError: String?

    let onComplete: () -> Void

    private var visibleCollections: [RecipeCollection] {
        guard excludeExisting else { return savedRecipesStore.collections }
        let existing = savedRecipesStore.savedRecipeCollections[recipe.id] ?? []
        return savedRecipesStore.collections.filter { !existing.contains($0.id) }
    }

    private var sheetTitle: String { excludeExisting ? "Add to Collection" : "Save to Collection" }

    private var isDoneOnly: Bool { excludeExisting && selectedCollectionIDs.isEmpty }

    private var confirmLabel: String {
        if isDoneOnly { return "Done" }
        return selectedCollectionIDs.isEmpty
            ? "Save"
            : "Add to \(selectedCollectionIDs.count) Collection\(selectedCollectionIDs.count == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.insideChip)

            HStack {
                Text(sheetTitle)
                    .sourdoughTextStyle(.title2, color: Sourdough.Colors.ink)
                Spacer()
                Button("Cancel") { dismiss() }
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.mutedInk)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.rowInternals)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Sourdough.Spacing.insideChip) {
                    ForEach(visibleCollections) { collection in
                        let isSelected = selectedCollectionIDs.contains(collection.id)
                        let count = savedRecipesStore.recipes(in: collection.id).count
                        Button {
                            toggleSet(&selectedCollectionIDs, collection.id)
                        } label: {
                            collectionRow(name: collection.name, count: count, isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                    }

                    if excludeExisting && visibleCollections.isEmpty {
                        Text(savedRecipesStore.collections.isEmpty
                             ? "You don't have any collections yet."
                             : "This recipe is already in all your collections.")
                            .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, Sourdough.Spacing.insideChip)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNewCollectionField.toggle()
                            if !showNewCollectionField { newCollectionName = "" }
                        }
                    } label: {
                        newCollectionRow
                    }
                    .buttonStyle(.plain)

                    if showNewCollectionField {
                        HStack(spacing: Sourdough.Spacing.insideChip) {
                            TextField("Collection name", text: $newCollectionName)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .sourdoughTextStyle(.body, color: Sourdough.Colors.ink)
                                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                                .frame(height: 48)
                                .background(Sourdough.Colors.sunken)
                                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))

                            Button {
                                createCollection()
                            } label: {
                                Ph.check.bold
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(Sourdough.Colors.onAction)
                                    .frame(width: 48, height: 48)
                                    .background(Sourdough.Ramp.sage500)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.insideChip)
            }
            .frame(maxHeight: .infinity)

            Button {
                if isDoneOnly {
                    onComplete()
                    dismiss()
                    return
                }
                Task {
                    isSaving = true
                    do {
                        try await savedRecipesStore.saveAndAddToCollections(recipe, toCollections: selectedCollectionIDs)
                        isSaving = false
                        onComplete()
                        dismiss()
                    } catch {
                        isSaving = false
                        saveError = error.localizedDescription
                    }
                }
            } label: {
                Text(confirmLabel)
                    .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.onAction)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Sourdough.Ramp.sage500)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.betweenBlocks - Sourdough.Spacing.insideChip)
        }
        .background(Sourdough.Colors.canvas)
        .presentationDragIndicator(.hidden)
        .task {
            await savedRecipesStore.fetchCollections()
            // Seed from actual membership so collections the recipe is already in show as
            // selected, instead of looking identical to ones it isn't in. In `excludeExisting`
            // mode those collections aren't shown at all, so there's nothing to pre-select.
            if !excludeExisting {
                selectedCollectionIDs.formUnion(savedRecipesStore.savedRecipeCollections[recipe.id] ?? [])
            }
        }
        .alert("Couldn't Save", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    // MARK: - Rows

    private func collectionRow(name: String, count: Int, isSelected: Bool) -> some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            Ph.folders.regular
                .frame(width: 18, height: 18)
                .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.mutedInk)
                .frame(width: 44, height: 44)
                .background(isSelected ? Sourdough.Colors.onAction.opacity(0.16) : Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .sourdoughTextStyle(.rowTitle, color: isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.ink)
                    .lineLimit(1)
                Text("\(count) recipe\(count == 1 ? "" : "s")")
                    .sourdoughTextStyle(.caption, color: isSelected ? Sourdough.Colors.onAction.opacity(0.85) : Sourdough.Colors.faintInk)
            }

            Spacer()

            (isSelected ? Ph.checkCircle.fill : Ph.circle.regular)
                .frame(width: 22, height: 22)
                .foregroundStyle(isSelected ? Sourdough.Colors.onAction : Sourdough.Colors.faintInk)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(Sourdough.Spacing.rowInternals)
        .background(isSelected ? Sourdough.Ramp.sage500 : Sourdough.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
    }

    private var newCollectionRow: some View {
        let active = showNewCollectionField
        return HStack(spacing: Sourdough.Spacing.rowInternals) {
            Ph.plus.regular
                .frame(width: 18, height: 18)
                .foregroundStyle(active ? Sourdough.Ramp.sage500 : Sourdough.Colors.mutedInk)
                .frame(width: 44, height: 44)
                .background(Sourdough.Colors.sunken)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.thumbnail, style: .continuous))

            Text("New Collection")
                .sourdoughTextStyle(.rowTitle, color: active ? Sourdough.Ramp.sage500 : Sourdough.Colors.mutedInk)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(Sourdough.Spacing.rowInternals)
        .background(Sourdough.Colors.card)
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
        .sourdoughElevation(.hairline, cornerRadius: Sourdough.Radius.card)
    }

    private func createCollection() {
        let name = newCollectionName
        isCreating = true
        Task {
            defer { isCreating = false }
            if let created = try? await savedRecipesStore.createCollection(name: name) {
                selectedCollectionIDs.insert(created.id)
                newCollectionName = ""
                withAnimation(.easeInOut(duration: 0.2)) { showNewCollectionField = false }
            }
        }
    }
}
