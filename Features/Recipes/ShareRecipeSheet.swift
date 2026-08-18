import SwiftUI
import PhotosUI
import AVFoundation
import PhosphorSwift

#Preview("Share Recipe Sheet") {
    PreviewContainer {
        ShareRecipeSheet()
    }
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
    @State private var timeMinutes: String
    @State private var servings: String
    @State private var ingredients: [(name: String, quantity: String, unit: String)]
    @State private var steps: [String]
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
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
        _timeMinutes = State(initialValue: prefill?.timeMinutes ?? "")
        _servings = State(initialValue: prefill?.servings ?? "")
        _ingredients = State(initialValue: prefill?.ingredients.isEmpty == false
            ? prefill!.ingredients
            : [(name: "", quantity: "", unit: "")])
        _steps = State(initialValue: prefill?.steps.isEmpty == false
            ? prefill!.steps
            : [""])
        _calories = State(initialValue: prefill?.calories ?? "")
        _protein = State(initialValue: prefill?.protein ?? "")
        _carbs = State(initialValue: prefill?.carbs ?? "")
        _fat = State(initialValue: prefill?.fat ?? "")
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

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && cuisine != nil
        && ingredients.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
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
                    formField("Photo (optional)") {
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
                                    Ph.camera.regular
                                        .frame(width: 24, height: 24)
                                        .foregroundStyle(Sourdough.Colors.faintInk)
                                    Text("Add Photo")
                                        .foregroundStyle(Sourdough.Colors.faintInk)
                                        .sourdoughTextStyle(.subhead)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
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

                    // Title field
                    formField("Title") {
                        formTextField("e.g. Grandma's Pasta", text: $title)
                    }

                    // Summary field
                    formField("Summary") {
                        formTextField("Brief description", text: $summary)
                    }

                    // Cuisine
                    formField("Cuisine") {
                        menuField(
                            options: Cuisine.allCases,
                            label: { $0.rawValue },
                            isSelected: { $0 == cuisine },
                            currentLabel: cuisine?.rawValue ?? "Select cuisine",
                            isPlaceholder: cuisine == nil
                        ) { option in
                            cuisine = cuisine == option ? nil : option
                        }
                    }

                    // Diet Type
                    formField("Diet Type") {
                        menuField(
                            options: GenerationOptions.DietType.allCases,
                            label: { $0.rawValue },
                            isSelected: { $0 == dietType },
                            currentLabel: dietType.rawValue,
                            isPlaceholder: false
                        ) { option in
                            dietType = option
                        }
                    }

                    // Dietary Restrictions
                    formField("Dietary Restrictions (optional)") {
                        Menu {
                            ForEach(GenerationOptions.DietaryRestriction.allCases) { option in
                                Button {
                                    if dietaryRestrictions.contains(option) {
                                        dietaryRestrictions.remove(option)
                                    } else {
                                        dietaryRestrictions.insert(option)
                                    }
                                } label: {
                                    HStack {
                                        Text(option.rawValue)
                                        if dietaryRestrictions.contains(option) {
                                            Ph.check.regular.frame(width: 16, height: 16)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(dietaryRestrictions.isEmpty
                                     ? "None"
                                     : dietaryRestrictions.map(\.rawValue).joined(separator: ", "))
                                    .foregroundStyle(dietaryRestrictions.isEmpty ? Sourdough.Colors.faintInk : Sourdough.Colors.ink)
                                    .sourdoughTextStyle(.body)
                                    .lineLimit(1)
                                Spacer()
                                Ph.caretDown.regular
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(Sourdough.Colors.faintInk)
                            }
                            .padding(.horizontal, Sourdough.Spacing.rowInternals)
                            .frame(height: 48)
                            .background(Sourdough.Colors.sunken)
                            .overlay(
                                RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                                    .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                        }
                    }

                    // Time & Servings
                    HStack(spacing: Sourdough.Spacing.rowInternals) {
                        formField("Time (min)") {
                            formTextField("e.g. 30", text: $timeMinutes)
                                .keyboardType(.numberPad)
                        }
                        formField("Servings") {
                            formTextField("e.g. 4", text: $servings)
                                .keyboardType(.numberPad)
                        }
                    }

                    // Ingredients
                    formField("Ingredients") {
                        ForEach(ingredients.indices, id: \.self) { index in
                            VStack(spacing: Sourdough.Spacing.insideChip) {
                                HStack(spacing: Sourdough.Spacing.insideChip) {
                                    formTextField("Qty", text: Binding(
                                        get: { ingredients[index].quantity },
                                        set: { ingredients[index].quantity = $0 }
                                    ))
                                    .keyboardType(.decimalPad)
                                    .frame(width: 64)

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
                                        .frame(height: 48)
                                        .frame(minWidth: 72)
                                        .background(Sourdough.Colors.sunken)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                                                .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                                    }

                                    formTextField("Ingredient", text: Binding(
                                        get: { ingredients[index].name },
                                        set: { ingredients[index].name = $0 }
                                    ))

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
                        }

                        Button {
                            ingredients.append((name: "", quantity: "", unit: ""))
                        } label: {
                            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                                Ph.plusCircle.fill
                                    .frame(width: 14, height: 14)
                                Text("Add Ingredient")
                                    .sourdoughTextStyle(.subhead)
                            }
                            .foregroundStyle(Sourdough.Colors.actionInk)
                        }
                        .buttonStyle(.plain)
                    }

                    // Steps
                    formField("Steps") {
                        ForEach(steps.indices, id: \.self) { index in
                            HStack(spacing: Sourdough.Spacing.insideChip) {
                                Text("\(index + 1).")
                                    .foregroundStyle(Sourdough.Colors.faintInk)
                                    .sourdoughTextStyle(.subhead)
                                    .frame(width: 20)

                                formTextField("Step \(index + 1)", text: $steps[index])

                                if steps.count > 1 {
                                    Button {
                                        steps.remove(at: index)
                                    } label: {
                                        Ph.minusCircle.fill
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(Sourdough.Colors.destructive)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button {
                            steps.append("")
                        } label: {
                            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                                Ph.plusCircle.fill
                                    .frame(width: 14, height: 14)
                                Text("Add Step")
                                    .sourdoughTextStyle(.subhead)
                            }
                            .foregroundStyle(Sourdough.Colors.actionInk)
                        }
                        .buttonStyle(.plain)
                    }

                    // Macros
                    formField("Macros (optional)") {
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

                    // Sources
                    formField("Sources (optional)") {
                        ForEach(sources.indices, id: \.self) { index in
                            VStack(spacing: Sourdough.Spacing.insideChip) {
                                HStack(spacing: Sourdough.Spacing.insideChip) {
                                    formTextField("Source title", text: Binding(
                                        get: { sources[index].title },
                                        set: { sources[index].title = $0 }
                                    ))

                                    Button {
                                        sources.remove(at: index)
                                    } label: {
                                        Ph.minusCircle.fill
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(Sourdough.Colors.destructive)
                                    }
                                    .buttonStyle(.plain)
                                }

                                formTextField("https://...", text: Binding(
                                    get: { sources[index].url },
                                    set: { sources[index].url = $0 }
                                ))
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                            }
                        }

                        Button {
                            sources.append((title: "", url: ""))
                        } label: {
                            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                                Ph.plusCircle.fill
                                    .frame(width: 14, height: 14)
                                Text("Add Source")
                                    .sourdoughTextStyle(.subhead)
                            }
                            .foregroundStyle(Sourdough.Colors.actionInk)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            // Save button
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

        let sourceLinks: [SourceLink] = sources.compactMap { source in
            let trimmedTitle = source.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedURL = source.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty, let url = URL(string: trimmedURL), !trimmedURL.isEmpty else {
                return nil
            }
            return SourceLink(title: trimmedTitle, url: url)
        }

        isSaving = true
        saveError = nil

        Task {
            do {
                try await savedRecipesStore.addSharedRecipe(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
                    timeMinutes: Int(timeMinutes) ?? 0,
                    servings: Int(servings) ?? 1,
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

    private func formField<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.insideChip) {
            Text(label)
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .sourdoughTextStyle(.caption)
            content()
        }
    }

    private func formTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .autocorrectionDisabled()
            .foregroundStyle(Sourdough.Colors.ink)
            .sourdoughTextStyle(.body)
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .frame(height: 48)
            .background(Sourdough.Colors.sunken)
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                    .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
    }

    /// Single-select dropdown row shared by the Cuisine and Diet Type fields — same menu/label
    /// chrome, differing only in the option list and what "selected" means for the caller.
    private func menuField<T: Hashable>(
        options: [T],
        label: @escaping (T) -> String,
        isSelected: @escaping (T) -> Bool,
        currentLabel: String,
        isPlaceholder: Bool,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button {
                    onSelect(option)
                } label: {
                    HStack {
                        Text(label(option))
                        if isSelected(option) {
                            Ph.check.regular.frame(width: 16, height: 16)
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(currentLabel)
                    .foregroundStyle(isPlaceholder ? Sourdough.Colors.faintInk : Sourdough.Colors.ink)
                    .sourdoughTextStyle(.body)
                Spacer()
                Ph.caretDown.regular
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Sourdough.Colors.faintInk)
            }
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .frame(height: 48)
            .background(Sourdough.Colors.sunken)
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                    .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
        }
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
                .frame(height: 48)
                .background(Sourdough.Colors.sunken)
                .overlay(
                    RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous)
                        .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
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
