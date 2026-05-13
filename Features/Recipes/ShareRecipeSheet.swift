import SwiftUI
import PhotosUI
import AVFoundation

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
    @State private var isEstimatingMacros: Bool
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
        _isEstimatingMacros = State(initialValue: false)
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
                .fill(DS.ColorToken.borderDefault)
                .frame(width: 36, height: 5)
                .padding(.top, DS.Spacing.space3)
                .padding(.bottom, DS.Spacing.space4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.space6) {
                    // Title + cancel
                    HStack {
                        Text(sheetTitle)
                            .appTextStyle(.heading2)
                            .foregroundStyle(DS.ColorToken.textPrimary)

                        Spacer()

                        Button("Cancel") { dismiss() }
                            .font(.custom("Satoshi Variable", size: 14))
                            .foregroundStyle(DS.ColorToken.textSecondary)
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
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))

                                Button {
                                    self.imageData = nil
                                    self.selectedPhoto = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                }
                                .buttonStyle(.plain)
                                .padding(DS.Spacing.space2)
                            }
                        } else {
                            Button {
                                showingImageSourcePicker = true
                            } label: {
                                VStack(spacing: DS.Spacing.space2) {
                                    Image(systemName: "camera")
                                        .font(.system(size: 24))
                                        .foregroundStyle(DS.ColorToken.textTertiary)
                                    Text("Add Photo")
                                        .appTextStyle(.bodySM)
                                        .foregroundStyle(DS.ColorToken.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(DS.ColorToken.bgSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                        .stroke(DS.ColorToken.borderDefault, style: StrokeStyle(lineWidth: 1, dash: [6]))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
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
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Text("Choose from Library")
                        }
                        Button("Cancel", role: .cancel) {}
                    }
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
                        FlowLayout(spacing: DS.Spacing.space2) {
                            ForEach(Cuisine.allCases) { option in
                                Button {
                                    cuisine = cuisine == option ? nil : option
                                } label: {
                                    Text(option.rawValue)
                                        .font(.custom("Satoshi Variable", size: 14))
                                        .foregroundStyle(cuisine == option ? .white : DS.ColorToken.textSecondary)
                                        .padding(.horizontal, DS.Spacing.space3)
                                        .frame(height: 36)
                                        .background(cuisine == option ? DS.ColorToken.midnight : DS.ColorToken.bgSecondary)
                                        .overlay(
                                            Capsule()
                                                .stroke(cuisine == option ? Color.clear : DS.ColorToken.borderDefault, lineWidth: 1)
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Diet Type
                    formField("Diet Type") {
                        FlowLayout(spacing: DS.Spacing.space2) {
                            ForEach(GenerationOptions.DietType.allCases) { option in
                                Button {
                                    dietType = dietType == option ? .any : option
                                } label: {
                                    let isSelected = dietType == option && option != .any
                                    Text(option.rawValue)
                                        .font(.custom("Satoshi Variable", size: 14))
                                        .foregroundStyle(isSelected ? .white : DS.ColorToken.textSecondary)
                                        .padding(.horizontal, DS.Spacing.space3)
                                        .frame(height: 36)
                                        .background(isSelected ? DS.ColorToken.midnight : DS.ColorToken.bgSecondary)
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color.clear : DS.ColorToken.borderDefault, lineWidth: 1)
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Dietary Restrictions
                    formField("Dietary Restrictions (optional)") {
                        FlowLayout(spacing: DS.Spacing.space2) {
                            ForEach(GenerationOptions.DietaryRestriction.allCases) { option in
                                Button {
                                    if dietaryRestrictions.contains(option) {
                                        dietaryRestrictions.remove(option)
                                    } else {
                                        dietaryRestrictions.insert(option)
                                    }
                                } label: {
                                    let isSelected = dietaryRestrictions.contains(option)
                                    Text(option.rawValue)
                                        .font(.custom("Satoshi Variable", size: 14))
                                        .foregroundStyle(isSelected ? .white : DS.ColorToken.textSecondary)
                                        .padding(.horizontal, DS.Spacing.space3)
                                        .frame(height: 36)
                                        .background(isSelected ? DS.ColorToken.midnight : DS.ColorToken.bgSecondary)
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color.clear : DS.ColorToken.borderDefault, lineWidth: 1)
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Time & Servings
                    HStack(spacing: DS.Spacing.space3) {
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
                            VStack(spacing: DS.Spacing.space2) {
                                HStack(spacing: DS.Spacing.space2) {
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
                                                .appTextStyle(.bodySM)
                                                .foregroundStyle(ingredients[index].unit.isEmpty ? DS.ColorToken.textTertiary : DS.ColorToken.textPrimary)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundStyle(DS.ColorToken.textTertiary)
                                        }
                                        .padding(.horizontal, DS.Spacing.space3)
                                        .frame(height: 48)
                                        .frame(minWidth: 72)
                                        .background(DS.ColorToken.bgSecondary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous)
                                                .stroke(DS.ColorToken.borderDefault, lineWidth: 1)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
                                    }

                                    formTextField("Ingredient", text: Binding(
                                        get: { ingredients[index].name },
                                        set: { ingredients[index].name = $0 }
                                    ))

                                    if ingredients.count > 1 {
                                        Button {
                                            ingredients.remove(at: index)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(DS.ColorToken.error)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Button {
                            ingredients.append((name: "", quantity: "", unit: ""))
                        } label: {
                            HStack(spacing: DS.Spacing.space1) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                Text("Add Ingredient")
                                    .font(.custom("Satoshi Variable", size: 14))
                            }
                            .foregroundStyle(DS.ColorToken.primary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Steps
                    formField("Steps") {
                        ForEach(steps.indices, id: \.self) { index in
                            HStack(spacing: DS.Spacing.space2) {
                                Text("\(index + 1).")
                                    .appTextStyle(.bodySM)
                                    .foregroundStyle(DS.ColorToken.textTertiary)
                                    .frame(width: 20)

                                formTextField("Step \(index + 1)", text: $steps[index])

                                if steps.count > 1 {
                                    Button {
                                        steps.remove(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(DS.ColorToken.error)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button {
                            steps.append("")
                        } label: {
                            HStack(spacing: DS.Spacing.space1) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                Text("Add Step")
                                    .font(.custom("Satoshi Variable", size: 14))
                            }
                            .foregroundStyle(DS.ColorToken.primary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Macros
                    formField("Macros (optional)") {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: DS.Spacing.space2),
                            GridItem(.flexible(), spacing: DS.Spacing.space2)
                        ], spacing: DS.Spacing.space2) {
                            macroField("Calories", text: $calories)
                            macroField("Protein (g)", text: $protein)
                            macroField("Carbs (g)", text: $carbs)
                            macroField("Fat (g)", text: $fat)
                        }

                        Button(action: estimateMacros) {
                            HStack(spacing: DS.Spacing.space2) {
                                if isEstimatingMacros {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(DS.ColorToken.primary)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 14))
                                }
                                Text(isEstimatingMacros ? "Estimating..." : "Get AI Estimate")
                                    .font(.custom("Satoshi Variable", size: 14))
                            }
                            .foregroundStyle(DS.ColorToken.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(DS.ColorToken.primaryLight)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isEstimatingMacros)
                    }

                    // Sources
                    formField("Sources (optional)") {
                        ForEach(sources.indices, id: \.self) { index in
                            VStack(spacing: DS.Spacing.space2) {
                                HStack(spacing: DS.Spacing.space2) {
                                    formTextField("Source title", text: Binding(
                                        get: { sources[index].title },
                                        set: { sources[index].title = $0 }
                                    ))

                                    Button {
                                        sources.remove(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(DS.ColorToken.error)
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
                            HStack(spacing: DS.Spacing.space1) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                Text("Add Source")
                                    .font(.custom("Satoshi Variable", size: 14))
                            }
                            .foregroundStyle(DS.ColorToken.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.space5)
            }

            // Save button
            Button(action: saveRecipe) {
                Group {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(sheetTitle)
                            .font(.custom("Satoshi Variable", size: 16))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [DS.ColorToken.primary, DS.ColorToken.primaryHover],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .opacity(canSave && !isSaving ? 1 : 0.4)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.full, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isSaving)
            .padding(.horizontal, DS.Spacing.space5)
            .padding(.top, DS.Spacing.space3)
            .padding(.bottom, DS.Spacing.space4)
        }
        .background(DS.ColorToken.bgPrimary)
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

    private func estimateMacros() {
        isEstimatingMacros = true
        Task {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 800...1200)))
            let servingCount = max(Int(servings) ?? 1, 1)
            let ingredientCount = ingredients.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            let baseCal = 250 + ingredientCount * 60
            let perServing = baseCal / servingCount
            calories = "\(perServing)"
            protein = "\(max(8, 18 + ingredientCount * 4) / servingCount)"
            carbs = "\(max(10, 30 + ingredientCount * 6) / servingCount)"
            fat = "\(max(5, 12 + ingredientCount * 3) / servingCount)"
            isEstimatingMacros = false
        }
    }

    // MARK: - Reusable Components

    private func formField<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space2) {
            Text(label)
                .appTextStyle(.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
            content()
        }
    }

    private func formTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
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

    private func macroField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.space1) {
            Text(label)
                .appTextStyle(.caption)
                .foregroundStyle(DS.ColorToken.textTertiary)

            TextField("0", text: text)
                .keyboardType(.numberPad)
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
