import SwiftUI
import PhotosUI
import AVFoundation
import PhosphorSwift

#Preview("Share Recipe Sheet") {
    PreviewContainer {
        ShareRecipeSheet()
    }
}

private enum SharePickerField: Hashable {
    case cuisine, diet, restrictions
}

struct ShareRecipeSheet: View {
    var sheetTitle: String
    var prefill: RecipeImportData?
    var isCookbookRecipe: Bool

    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showingImageSourcePicker: Bool
    @State private var showingCamera: Bool
    @State private var showingPhotoPicker: Bool
    @State private var showingCameraDeniedAlert: Bool
    @State private var title: String
    @State private var summary: String
    @State private var cuisine: Cuisine?
    @State private var dietType: GenerationOptions.DietType
    @State private var dietaryRestrictions: Set<GenerationOptions.DietaryRestriction>
    @State private var openPicker: SharePickerField?
    @State private var timeMinutes: String
    @State private var servings: Int
    @State private var ingredients: [(name: String, quantity: String, unit: String)]
    @State private var steps: [String]
    @State private var macrosOpen: Bool
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var sourcesOpen: Bool
    @State private var sources: [(title: String, url: String)]
    @State private var isSaving: Bool
    @State private var saveError: String?

    init(sheetTitle: String = "Share Recipe", prefill: RecipeImportData? = nil, isCookbookRecipe: Bool = false) {
        self.sheetTitle = sheetTitle
        self.prefill = prefill
        self.isCookbookRecipe = isCookbookRecipe
        _selectedPhoto = State(initialValue: nil)
        _imageData = State(initialValue: prefill?.imageData)
        _showingImageSourcePicker = State(initialValue: false)
        _showingCamera = State(initialValue: false)
        _showingPhotoPicker = State(initialValue: false)
        _showingCameraDeniedAlert = State(initialValue: false)
        _title = State(initialValue: prefill?.title ?? "")
        _summary = State(initialValue: prefill?.summary ?? "")
        _cuisine = State(initialValue: prefill?.cuisine)
        _dietType = State(initialValue: .any)
        _dietaryRestrictions = State(initialValue: [])
        _openPicker = State(initialValue: nil)
        _timeMinutes = State(initialValue: prefill?.timeMinutes ?? "")
        _servings = State(initialValue: Int(prefill?.servings ?? "") ?? 1)
        _ingredients = State(initialValue: prefill?.ingredients.isEmpty == false
            ? prefill!.ingredients
            : [(name: "", quantity: "", unit: "")])
        _steps = State(initialValue: prefill?.steps.isEmpty == false
            ? prefill!.steps
            : [""])
        _macrosOpen = State(initialValue: false)
        _calories = State(initialValue: prefill?.calories ?? "")
        _protein = State(initialValue: prefill?.protein ?? "")
        _carbs = State(initialValue: prefill?.carbs ?? "")
        _fat = State(initialValue: prefill?.fat ?? "")
        _sourcesOpen = State(initialValue: false)
        _sources = State(initialValue: {
            if let p = prefill, !p.sourceURL.isEmpty {
                return [(title: p.sourceTitle, url: p.sourceURL)]
            }
            return []
        }())
        _isSaving = State(initialValue: false)
        _saveError = State(initialValue: nil)
    }

    private let ingredientUnits = ["tsp", "tbsp", "cup", "oz", "fl oz", "lb", "g", "kg", "ml", "L", "pcs", "pinch", "can", "bunch", "cloves"]
    private let expandSpring = Animation.spring(response: 0.35, dampingFraction: 0.75)

    /// Ordered so the sticky footer's "Still needed: …" helper line reads in a sensible sequence.
    /// Diet type isn't gated (it always has the `.any` default) and dietary restrictions aren't
    /// gated (an empty set correctly means "no restrictions," not "undecided") — see plan Deviation 3.
    private var validationChecks: [(label: String, ok: Bool)] {
        let trimmedName = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasIngredient = ingredients.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasStep = steps.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return [
            (label: "a recipe name", ok: !trimmedName.isEmpty),
            (label: "a description (20+ characters)", ok: trimmedDesc.count >= 20),
            (label: "a cuisine", ok: cuisine != nil),
            (label: "a time", ok: (Int(timeMinutes) ?? 0) > 0),
            (label: "servings", ok: servings > 0),
            (label: "at least one ingredient", ok: hasIngredient),
            (label: "at least one step", ok: hasStep)
        ]
    }

    private var canSave: Bool {
        validationChecks.allSatisfy(\.ok)
    }

    private var missingFieldsHelp: String {
        "Still needed: " + validationChecks.filter { !$0.ok }.map(\.label).joined(separator: ", ")
    }

    private var macroFilledCount: Int {
        [calories, protein, carbs, fat].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Sourdough.Colors.hairline)
                .frame(width: 36, height: 5)
                .padding(.top, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.screenMargin)

            ScrollView(showsIndicators: false) {
                VStack(spacing: Sourdough.Spacing.betweenBlocks) {
                    // Title + cancel
                    HStack {
                        Text(sheetTitle)
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.title2)

                        Spacer()

                        Button("Cancel") { dismiss() }
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.subhead)
                            .buttonStyle(.plain)
                    }

                    // Photo picker
                    photoField
                        .onChange(of: selectedPhoto) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    imageData = data
                                }
                            }
                        }
                        .confirmationDialog("Add Photo", isPresented: $showingImageSourcePicker) {
                            Button("Take Photo") {
                                requestCameraAccess()
                            }
                            Button("Choose from Library") {
                                showingPhotoPicker = true
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhoto, matching: .images)
                        .fullScreenCover(isPresented: $showingCamera) {
                            CameraImagePicker(imageData: $imageData)
                                .ignoresSafeArea()
                        }
                        .alert("Camera Access", isPresented: $showingCameraDeniedAlert) {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("UseUp needs camera access to take photos of your recipes. You can enable this in Settings.")
                        }

                    // Recipe name
                    sectionCard(label: "Recipe name") {
                        TextField("Spinach & yogurt flatbreads", text: $title)
                            .autocorrectionDisabled()
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.rowTitle)
                    }

                    // Description
                    sectionCard(label: "Description", count: "\(summary.trimmingCharacters(in: .whitespacesAndNewlines).count) / 20") {
                        ZStack(alignment: .topLeading) {
                            if summary.isEmpty {
                                Text("What it tastes like, and what it saves from the fridge.")
                                    .foregroundStyle(Sourdough.Colors.faintInk)
                                    .sourdoughTextStyle(.body)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $summary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 66)
                                .foregroundStyle(Sourdough.Colors.ink)
                                .sourdoughTextStyle(.body)
                        }
                    }

                    // Cuisine
                    inlinePickerRow(
                        label: "Cuisine",
                        options: Cuisine.allCases,
                        optionLabel: { $0.rawValue },
                        isSelected: { $0 == cuisine },
                        valueText: cuisine?.rawValue ?? "Choose one",
                        isPlaceholder: cuisine == nil,
                        isOpen: openPicker == .cuisine
                    ) {
                        withAnimation(expandSpring) { openPicker = openPicker == .cuisine ? nil : .cuisine }
                    } onPick: { option in
                        cuisine = cuisine == option ? nil : option
                        withAnimation(expandSpring) { openPicker = nil }
                    }

                    // Diet Type
                    inlinePickerRow(
                        label: "Diet Type",
                        options: GenerationOptions.DietType.allCases,
                        optionLabel: { $0.rawValue },
                        isSelected: { $0 == dietType },
                        valueText: dietType.rawValue,
                        isPlaceholder: false,
                        isOpen: openPicker == .diet
                    ) {
                        withAnimation(expandSpring) { openPicker = openPicker == .diet ? nil : .diet }
                    } onPick: { option in
                        dietType = option
                        withAnimation(expandSpring) { openPicker = nil }
                    }

                    // Dietary Restrictions
                    inlinePickerRow(
                        label: "Dietary Restrictions",
                        options: GenerationOptions.DietaryRestriction.allCases,
                        optionLabel: { $0.rawValue },
                        isSelected: { dietaryRestrictions.contains($0) },
                        valueText: dietaryRestrictions.isEmpty ? "None" : dietaryRestrictions.map(\.rawValue).joined(separator: ", "),
                        isPlaceholder: dietaryRestrictions.isEmpty,
                        isOpen: openPicker == .restrictions
                    ) {
                        withAnimation(expandSpring) { openPicker = openPicker == .restrictions ? nil : .restrictions }
                    } onPick: { option in
                        if dietaryRestrictions.contains(option) {
                            dietaryRestrictions.remove(option)
                        } else {
                            dietaryRestrictions.insert(option)
                        }
                    }

                    // Time & Servings
                    HStack(spacing: Sourdough.Spacing.rowInternals) {
                        sectionCard(label: "Time") {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                TextField("20", text: $timeMinutes)
                                    .keyboardType(.numberPad)
                                    .foregroundStyle(Sourdough.Colors.ink)
                                    .sourdoughTextStyle(.title2)
                                Text("min")
                                    .foregroundStyle(Sourdough.Colors.mutedInk)
                                    .sourdoughTextStyle(.subhead)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        sectionCard(label: "Servings") {
                            HStack {
                                Button {
                                    servings = max(1, servings - 1)
                                } label: {
                                    Text("−")
                                        .foregroundStyle(servings > 1 ? Sourdough.Colors.ink : Sourdough.Colors.faintInk)
                                        .sourdoughTextStyle(.rowTitle)
                                        .frame(width: 32, height: 32)
                                        .background(Sourdough.Colors.sunken)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)

                                Spacer()
                                Text("\(servings)")
                                    .foregroundStyle(Sourdough.Colors.ink)
                                    .sourdoughTextStyle(.title2)
                                Spacer()

                                Button {
                                    servings = min(24, servings + 1)
                                } label: {
                                    Text("+")
                                        .foregroundStyle(Sourdough.Colors.actionInk)
                                        .sourdoughTextStyle(.rowTitle)
                                        .frame(width: 32, height: 32)
                                        .background(Sourdough.Ramp.terracotta100)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(width: 168)
                    }

                    // Ingredients
                    sectionCard(
                        label: "Ingredients",
                        count: "\(ingredients.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count) of \(ingredients.count) complete"
                    ) {
                        VStack(spacing: Sourdough.Spacing.insideChip) {
                            ForEach(ingredients.indices, id: \.self) { index in
                                HStack(spacing: Sourdough.Spacing.insideChip) {
                                    nestedTextField("1", text: Binding(
                                        get: { ingredients[index].quantity },
                                        set: { ingredients[index].quantity = $0 }
                                    ), style: .title2, alignment: .center)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 56)

                                    Menu {
                                        Button("none") { ingredients[index].unit = "" }
                                        ForEach(ingredientUnits, id: \.self) { unit in
                                            Button(unit) { ingredients[index].unit = unit }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(ingredients[index].unit.isEmpty ? "Unit" : ingredients[index].unit)
                                                .foregroundStyle(ingredients[index].unit.isEmpty ? Sourdough.Colors.faintInk : Sourdough.Colors.ink)
                                                .sourdoughTextStyle(.subhead)
                                            Ph.caretDown.bold
                                                .frame(width: 10, height: 10)
                                                .foregroundStyle(Sourdough.Colors.faintInk)
                                        }
                                        .padding(.horizontal, Sourdough.Spacing.rowInternals)
                                        .frame(height: 44)
                                        .frame(minWidth: 72)
                                        .background(Sourdough.Colors.sunken)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous)
                                                .stroke(Sourdough.Colors.hairline, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))
                                    }

                                    nestedTextField("Baby spinach", text: Binding(
                                        get: { ingredients[index].name },
                                        set: { ingredients[index].name = $0 }
                                    ), style: .body, alignment: .leading)

                                    if ingredients.count > 1 {
                                        Button {
                                            ingredients.remove(at: index)
                                        } label: {
                                            Ph.minusCircle.fill
                                                .frame(width: 16, height: 16)
                                                .foregroundStyle(Sourdough.Colors.destructive)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            addRowButton("Add Ingredient") {
                                ingredients.append((name: "", quantity: "", unit: ""))
                            }
                        }
                    }

                    // Steps
                    sectionCard(
                        label: "Method",
                        count: "\(steps.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count) of \(steps.count) written"
                    ) {
                        VStack(spacing: Sourdough.Spacing.insideChip) {
                            ForEach(steps.indices, id: \.self) { index in
                                HStack(alignment: .top, spacing: Sourdough.Spacing.insideChip) {
                                    Text("\(index + 1)")
                                        .foregroundStyle(Sourdough.Ramp.sage600)
                                        .sourdoughTextStyle(.caption)
                                        .frame(width: 26, height: 26)
                                        .background(Sourdough.Ramp.sage100)
                                        .clipShape(Circle())
                                        .padding(.top, 7)

                                    ZStack(alignment: .topLeading) {
                                        if steps[index].isEmpty {
                                            Text("Warm the flatbreads dry in a pan.")
                                                .foregroundStyle(Sourdough.Colors.faintInk)
                                                .sourdoughTextStyle(.body)
                                                .padding(.top, 8)
                                                .padding(.leading, 5)
                                                .allowsHitTesting(false)
                                        }
                                        TextEditor(text: $steps[index])
                                            .scrollContentBackground(.hidden)
                                            .frame(minHeight: 44)
                                            .foregroundStyle(Sourdough.Colors.ink)
                                            .sourdoughTextStyle(.body)
                                    }
                                    .padding(.horizontal, 4)
                                    .background(Sourdough.Colors.canvas)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous)
                                            .stroke(Sourdough.Colors.hairline, lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))

                                    if steps.count > 1 {
                                        Button {
                                            steps.remove(at: index)
                                        } label: {
                                            Ph.minusCircle.fill
                                                .frame(width: 16, height: 16)
                                                .foregroundStyle(Sourdough.Colors.destructive)
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.top, 10)
                                    }
                                }
                            }

                            addRowButton("Add Step") {
                                steps.append("")
                            }
                        }
                    }

                    // Macros (collapsible)
                    collapsibleCard(
                        title: "Macros",
                        summary: macroFilledCount > 0 ? "\(macroFilledCount) of 4 filled · per serving" : "Optional · per serving",
                        isOpen: macrosOpen
                    ) {
                        withAnimation(expandSpring) { macrosOpen.toggle() }
                    } content: {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: Sourdough.Spacing.insideChip),
                            GridItem(.flexible(), spacing: Sourdough.Spacing.insideChip)
                        ], spacing: Sourdough.Spacing.insideChip) {
                            macroField("Calories", text: $calories)
                            macroField("Protein (g)", text: $protein)
                            macroField("Carbs (g)", text: $carbs)
                            macroField("Fat (g)", text: $fat)
                        }
                    }

                    // Sources (collapsible)
                    collapsibleCard(
                        title: "Sources",
                        summary: sources.isEmpty ? "Optional · credit where it came from" : "\(sources.count) link\(sources.count > 1 ? "s" : "")",
                        isOpen: sourcesOpen
                    ) {
                        withAnimation(expandSpring) { sourcesOpen.toggle() }
                    } content: {
                        VStack(spacing: Sourdough.Spacing.insideChip) {
                            ForEach(sources.indices, id: \.self) { index in
                                HStack(spacing: Sourdough.Spacing.insideChip) {
                                    nestedTextField("https:// or a cookbook page", text: Binding(
                                        get: { sources[index].url },
                                        set: { sources[index].url = $0 }
                                    ), style: .body, alignment: .leading)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)

                                    Button {
                                        sources.remove(at: index)
                                    } label: {
                                        Ph.minusCircle.fill
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(Sourdough.Colors.destructive)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            addRowButton("Add Link") {
                                sources.append((title: "", url: ""))
                            }
                        }
                    }
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            // Save button
            VStack(spacing: Sourdough.Spacing.iconToLabel) {
                Button(action: saveRecipe) {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text(sheetTitle)
                                .foregroundStyle(Sourdough.Colors.onAction)
                                .sourdoughTextStyle(.rowTitle)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [Sourdough.Colors.action, Sourdough.Colors.actionInk],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        )
                        .opacity(canSave && !isSaving ? 1 : 0.4)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSave || isSaving)

                Text(canSave ? "Shared with the community once submitted" : missingFieldsHelp)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .background(Sourdough.Colors.canvas)
        .alert("Could not save recipe", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Photo field

    @ViewBuilder
    private var photoField: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))

                Button {
                    self.imageData = nil
                    self.selectedPhoto = nil
                } label: {
                    Ph.xCircle.fill
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Sourdough.Colors.onAction)
                        .shadow(radius: 2)
                }
                .buttonStyle(.plain)
                .padding(Sourdough.Spacing.insideChip)
            }
        } else {
            Button {
                showingImageSourcePicker = true
            } label: {
                VStack(spacing: Sourdough.Spacing.insideChip) {
                    Circle()
                        .fill(Sourdough.Ramp.terracotta100)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Ph.camera.regular
                                .frame(width: 21, height: 21)
                                .foregroundStyle(Sourdough.Colors.actionInk)
                        )
                    Text("Add a Photo")
                        .foregroundStyle(Sourdough.Colors.ink)
                        .sourdoughTextStyle(.subhead)
                    Text("Camera or library · optional but recommended")
                        .foregroundStyle(Sourdough.Colors.faintInk)
                        .sourdoughTextStyle(.caption)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 168)
                .background(Sourdough.Colors.sunken)
                .overlay(
                    RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                        .stroke(Sourdough.Colors.interactiveBorder, style: StrokeStyle(lineWidth: 1, dash: [6]))
                )
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func requestCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        showingCameraDeniedAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingCameraDeniedAlert = true
        @unknown default:
            showingCameraDeniedAlert = true
        }
    }

    private func saveRecipe() {
        let filteredIngredients: [RecipeIngredient] = ingredients
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map {
                let qty = $0.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
                let unit = $0.unit.trimmingCharacters(in: .whitespacesAndNewlines)
                let combined = [qty, unit].filter { !$0.isEmpty }.joined(separator: " ")
                return RecipeIngredient(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), quantity: combined)
            }

        let filteredSteps = steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Source rows only collect a URL now; when no explicit title was ever set (the common
        // case), derive one from the URL's host rather than dropping the source — the original
        // `title`-required filter would otherwise silently discard every row.
        let sourceLinks: [SourceLink] = sources.compactMap { source in
            let trimmedURL = source.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedURL.isEmpty, let url = URL(string: trimmedURL) else { return nil }
            let trimmedTitle = source.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let derivedTitle = trimmedTitle.isEmpty
                ? (url.host?.replacingOccurrences(of: "www.", with: "") ?? trimmedURL)
                : trimmedTitle
            return SourceLink(title: derivedTitle, url: url)
        }

        isSaving = true
        saveError = nil

        Task {
            do {
                try await savedRecipesStore.addSharedRecipe(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                    timeMinutes: Int(timeMinutes) ?? 0,
                    servings: servings,
                    ingredients: filteredIngredients,
                    steps: filteredSteps,
                    macros: Macros(
                        calories: Int(calories) ?? 0,
                        proteinG: Int(protein) ?? 0,
                        carbsG: Int(carbs) ?? 0,
                        fatG: Int(fat) ?? 0
                    ),
                    sources: sourceLinks,
                    imageData: imageData,
                    cuisine: cuisine ?? .other,
                    dietType: dietType.rawValue.lowercased(),
                    dietaryRestrictions: dietaryRestrictions.map(\.rawValue),
                    isPublic: !isCookbookRecipe,
                    isUserShared: !isCookbookRecipe
                )
                dismiss()
            } catch {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }

    // MARK: - Reusable Components

    /// Bordered card used for simple single-content fields (name, description, ingredients,
    /// steps, time, servings) — label caption, optional right-aligned count, then content.
    private func sectionCard<Content: View>(
        label: String,
        count: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .foregroundStyle(Sourdough.Colors.mutedInk)
                    .sourdoughTextStyle(.caption)
                Spacer()
                if let count {
                    Text(count)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                        .sourdoughTextStyle(.caption)
                }
            }
            content()
        }
        .padding(Sourdough.Spacing.rowInternals)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(Sourdough.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
    }

    /// Single- or multi-select row that expands an inline wrapped chip grid on tap, instead of a
    /// native `Menu` popover — mirrors the emoji icon picker's spring/transition in
    /// `PantryView.swift`'s `IngredientFormContent`.
    private func inlinePickerRow<T: Hashable>(
        label: String,
        options: [T],
        optionLabel: @escaping (T) -> String,
        isSelected: @escaping (T) -> Bool,
        valueText: String,
        isPlaceholder: Bool,
        isOpen: Bool,
        onToggle: @escaping () -> Void,
        onPick: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(label)
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                            .sourdoughTextStyle(.caption)
                        Text(valueText)
                            .foregroundStyle(isPlaceholder ? Sourdough.Colors.faintInk : Sourdough.Colors.ink)
                            .sourdoughTextStyle(.body)
                            .lineLimit(1)
                    }
                    Spacer()
                    Ph.caretDown.regular
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(Sourdough.Spacing.rowInternals)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                FlowLayout(spacing: 7) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            onPick(option)
                        } label: {
                            Text(optionLabel(option))
                                .foregroundStyle(isSelected(option) ? Sourdough.Colors.onAction : Sourdough.Colors.ink)
                                .sourdoughTextStyle(.subhead)
                                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                                .frame(height: 36)
                                .background(isSelected(option) ? Sourdough.Ramp.sage600 : Sourdough.Colors.sunken)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .padding(.bottom, Sourdough.Spacing.rowInternals)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(Sourdough.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
    }

    /// Toggle-header card used by Macros and Sources — title + summary + caret, expanding to
    /// reveal `content` inline. Same card chrome as `inlinePickerRow`.
    private func collapsibleCard<Content: View>(
        title: String,
        summary: String,
        isOpen: Bool,
        onToggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .foregroundStyle(Sourdough.Colors.ink)
                            .sourdoughTextStyle(.rowTitle)
                        Text(summary)
                            .foregroundStyle(Sourdough.Colors.faintInk)
                            .sourdoughTextStyle(.caption)
                    }
                    Spacer()
                    Ph.caretDown.regular
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Sourdough.Colors.faintInk)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(Sourdough.Spacing.rowInternals)
            }
            .buttonStyle(.plain)

            if isOpen {
                content()
                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                    .padding(.bottom, Sourdough.Spacing.rowInternals)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(Sourdough.Colors.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
    }

    /// Lighter-fill field nested inside a `sectionCard` (ingredient qty/name, step, source-url
    /// rows) — one step lighter than the card itself, matching the design's card-within-card look.
    private func nestedTextField(_ placeholder: String, text: Binding<String>, style: Sourdough.Typography.Style, alignment: TextAlignment) -> some View {
        TextField(placeholder, text: text)
            .autocorrectionDisabled()
            .multilineTextAlignment(alignment)
            .foregroundStyle(Sourdough.Colors.ink)
            .sourdoughTextStyle(style)
            .padding(.horizontal, Sourdough.Spacing.insideChip)
            .frame(height: 44)
            .background(Sourdough.Colors.canvas)
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous)
                    .stroke(Sourdough.Colors.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))
    }

    private func addRowButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                Ph.plusCircle.fill
                    .frame(width: 14, height: 14)
                Text(title)
                    .sourdoughTextStyle(.subhead)
            }
            .foregroundStyle(Sourdough.Colors.actionInk)
        }
        .buttonStyle(.plain)
    }

    private func macroField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.iconToLabel) {
            Text(label)
                .foregroundStyle(Sourdough.Colors.faintInk)
                .sourdoughTextStyle(.caption)

            TextField("0", text: text)
                .keyboardType(.numberPad)
                .foregroundStyle(Sourdough.Colors.ink)
                .sourdoughTextStyle(.body)
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .frame(height: 44)
                .background(Sourdough.Colors.canvas)
                .overlay(
                    RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous)
                        .stroke(Sourdough.Colors.hairline, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))
        }
    }
}

// MARK: - Camera Image Picker

private struct CameraImagePicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraImagePicker

        init(_ parent: CameraImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
