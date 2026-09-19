import SwiftUI
import AVFoundation
import PhosphorSwift

/// Snap Chef — the one-tap "photo → single recipe" flow, presented as a full-screen cover from
/// the Generate screen. Reuses the shared camera, the photo-scan identification pipeline, the
/// recipe-generation loading animation, and `RecipeDetailView`.
struct SnapChefFlow: View {
    let recipeGenerator: RecipeGenerating
    let onFinished: () -> Void

    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var savedRecipesStore: SavedRecipesStore

    private let scanner: FoodPhotoIdentifying = TestingMode.isEnabled ? MockFoodPhotoScanner() : SupabaseFoodPhotoScanner()

    enum Phase { case tips, camera, identifying, review, loading, result }

    @State private var phase: Phase
    @State private var ingredients: [SnapChefIngredient] = []
    @State private var resultRecipe: Recipe?
    @State private var pushedRecipe: Recipe?
    @State private var generationError: Error?
    @State private var isEditingDetectedIngredients = false
    @FocusState private var focusedIngredientID: UUID?

    @State private var captureRequested = false
    @State private var torchOn = false
    @State private var showScanFailedAlert = false

    @State private var identifyTask: Task<Void, Never>?
    @State private var generationTask: Task<Void, Never>?

    init(recipeGenerator: RecipeGenerating, onFinished: @escaping () -> Void) {
        self.recipeGenerator = recipeGenerator
        self.onFinished = onFinished
        let tipsHidden = UserDefaults.standard.bool(forKey: PhotoScanTipsContext.snapChef.hideFlagKey)
        let cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        _phase = State(initialValue: (!tipsHidden || !cameraAuthorized) ? .tips : .camera)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $pushedRecipe) { recipe in
                    RecipeDetailView(recipe: recipe)
                }
        }
        .alert("Photo couldn't be processed", isPresented: $showScanFailedAlert) {
            Button("Retake") { phase = .camera }
            Button("Cancel", role: .cancel) { onFinished() }
        } message: {
            Text("We couldn't read that photo. Try again with better light and a clearer frame.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .tips:
            PhotoScanTipsView(
                context: .snapChef,
                onContinue: { phase = .camera },
                onCancel: onFinished
            )

        case .camera:
            cameraView

        case .identifying:
            statusView("Reading your ingredients…")

        case .review:
            SnapChefReviewView(
                ingredients: $ingredients,
                onConfirm: { startGeneration() },
                onRetake: { phase = .camera },
                onCancel: onFinished
            )

        case .loading:
            if let generationError {
                generationErrorView(generationError)
            } else {
                RecipeGenerationLoadingView()
                    .background(Sourdough.Colors.canvas)
            }

        case .result:
            if let resultRecipe {
                resultView(resultRecipe)
            } else {
                statusView("…")
            }
        }
    }

    // MARK: - Camera

    private var cameraView: some View {
        ZStack {
            PhotoScanCameraRepresentable(captureRequested: $captureRequested, torchOn: torchOn, onCapture: handleCapture)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    circleButton(Ph.x.bold) { onFinished() }
                    Spacer()
                    circleButton(Ph.question.bold) { phase = .tips }
                    circleButton(torchOn ? Ph.lightbulb.fill : Ph.lightbulb.regular) { torchOn.toggle() }
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.insideChip)

                Spacer()

                Text("Fit your ingredients in the frame")
                    .sourdoughTextStyle(.subhead, color: .white)
                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                    .padding(.vertical, Sourdough.Spacing.insideChip)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Capsule())
                    .padding(.bottom, Sourdough.Spacing.rowInternals)

                Button { captureRequested = true } label: {
                    ZStack {
                        Circle().stroke(Color.white, lineWidth: 4).frame(width: 72, height: 72)
                        Circle().fill(Color.white).frame(width: 58, height: 58)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, Sourdough.Spacing.betweenBlocks)
            }
        }
        .background(Color.black)
    }

    private func circleButton(_ icon: Image, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon
                .frame(width: 17, height: 17)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.4))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func statusView(_ label: String) -> some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            ProgressView()
            Text(label)
                .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Sourdough.Colors.canvas)
    }

    // MARK: - Result

    private func resultView(_ recipe: Recipe) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Sourdough.Spacing.betweenBlocks) {
                HStack {
                    Text("Your recipe")
                        .sourdoughTextStyle(.title2, color: Sourdough.Colors.ink)
                    Spacer()
                    circleButtonSunken(Ph.x.bold) { onFinished() }
                }

                Button { pushedRecipe = recipe } label: {
                    RecipeCard(
                        recipe: recipe,
                        showBadge: false,
                        isSaved: savedRecipesStore.isSaved(recipe),
                        imageAspectRatio: 16 / 9,
                        onSave: {
                            if savedRecipesStore.isSaved(recipe) {
                                savedRecipesStore.unsaveRecipe(recipe)
                            } else {
                                savedRecipesStore.saveGeneratedRecipe(recipe)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)

                Text("Tap the card for the full recipe, ingredients and steps.")
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                    .frame(maxWidth: .infinity, alignment: .center)

                ingredientReviewSection

                regenerateButton
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.top, Sourdough.Spacing.rowInternals)
            .padding(.bottom, Sourdough.Spacing.underTitle)
        }
        .background(Sourdough.Colors.canvas)
    }

    private func circleButtonSunken(_ icon: Image, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon
                .frame(width: 12, height: 12)
                .foregroundStyle(Sourdough.Colors.mutedInk)
                .frame(width: 30, height: 30)
                .background(Sourdough.Colors.sunken)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ingredient review (post-generation recap)

    private var ingredientReviewSection: some View {
        VStack(alignment: .leading, spacing: Sourdough.Spacing.rowInternals) {
            HStack(spacing: Sourdough.Spacing.rowInternals) {
                Text("What we used")
                    .sourdoughTextStyle(.rowTitle, color: Sourdough.Colors.ink)
                Spacer(minLength: 0)
                if !isEditingDetectedIngredients {
                    editPillButton
                }
            }

            ForEach($ingredients) { $item in
                detectedIngredientRow($item)
            }

            if isEditingDetectedIngredients {
                addDetectedIngredientButton
                saveIngredientEditsButton
            }
        }
    }

    private var hasUsableDetectedIngredient: Bool {
        ingredients.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var saveIngredientEditsButton: some View {
        Button {
            focusedIngredientID = nil
            isEditingDetectedIngredients = false
        } label: {
            Text("Save")
                .foregroundStyle(Sourdough.Colors.onAction)
                .sourdoughTextStyle(.rowTitle)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Sourdough.Colors.action)
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!hasUsableDetectedIngredient)
        .opacity(hasUsableDetectedIngredient ? 1 : 0.5)
    }

    private var editPillButton: some View {
        Button {
            isEditingDetectedIngredients = true
        } label: {
            Text("Edit")
                .sourdoughTextStyle(.subhead, color: Sourdough.Colors.action)
                .padding(.horizontal, Sourdough.Spacing.rowInternals)
                .frame(height: 36)
                .overlay(Capsule().stroke(Sourdough.Colors.action, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private func detectedIngredientRow(_ item: Binding<SnapChefIngredient>) -> some View {
        HStack(spacing: Sourdough.Spacing.rowInternals) {
            if isEditingDetectedIngredients {
                HStack(alignment: .top, spacing: Sourdough.Spacing.rowInternals) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NAME")
                            .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                        TextField("Ingredient", text: item.name)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .sourdoughTextStyle(.body, color: Sourdough.Colors.ink)
                            .focused($focusedIngredientID, equals: item.wrappedValue.id)
                            .submitLabel(.done)
                            .padding(.horizontal, Sourdough.Spacing.insideChip)
                            .frame(height: 40)
                            .background(Sourdough.Colors.sunken)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("QTY")
                            .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                        TextField("Amount", text: item.amount)
                            .keyboardType(.decimalPad)
                            .sourdoughTextStyle(.body, color: Sourdough.Colors.ink)
                            .padding(.horizontal, Sourdough.Spacing.insideChip)
                            .frame(height: 40)
                            .background(Sourdough.Colors.sunken)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))
                    }
                    .frame(width: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("UNIT")
                            .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                        Menu {
                            ForEach(UnitMeasurement.pickerUnits) { unit in
                                Button {
                                    item.wrappedValue.unit = unit
                                } label: {
                                    HStack {
                                        Text(unit.chipLabel)
                                        if item.wrappedValue.unit == unit {
                                            Ph.check.regular.frame(width: 16, height: 16)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(item.wrappedValue.unit.chipLabel.isEmpty ? "unit" : item.wrappedValue.unit.chipLabel)
                                    .sourdoughTextStyle(.body, color: item.wrappedValue.unit == .none ? Sourdough.Colors.faintInk : Sourdough.Colors.ink)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Ph.caretDown.regular
                                    .frame(width: 9, height: 9)
                                    .foregroundStyle(Sourdough.Colors.faintInk)
                            }
                            .padding(.horizontal, Sourdough.Spacing.insideChip)
                            .frame(height: 40)
                            .background(Sourdough.Colors.sunken)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))
                        }
                    }
                    .frame(width: 86)

                    Button {
                        ingredients.removeAll { $0.id == item.wrappedValue.id }
                    } label: {
                        Ph.trash.regular
                            .frame(width: 15, height: 15)
                            .foregroundStyle(Sourdough.Colors.mutedInk)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 22)
                }
            } else {
                Text(item.wrappedValue.name.capitalized)
                    .sourdoughTextStyle(.body, color: Sourdough.Colors.ink)
                Spacer()
                let quantity = displayQuantity(item.wrappedValue)
                if !quantity.isEmpty {
                    Text(quantity)
                        .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
                }
                if item.wrappedValue.lowConfidence {
                    Ph.warning.regular
                        .frame(width: 12, height: 12)
                        .foregroundStyle(Sourdough.Ramp.honey700)
                }
            }
        }
        .padding(Sourdough.Spacing.rowInternals)
        .background(Sourdough.Colors.card)
        .overlay(
            RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                .stroke(Sourdough.Colors.interactiveBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous))
    }

    private var addDetectedIngredientButton: some View {
        Button {
            let new = SnapChefIngredient(name: "")
            ingredients.append(new)
            focusedIngredientID = new.id
        } label: {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                Ph.plus.bold.frame(width: 13, height: 13)
                Text("Add an ingredient")
            }
            .foregroundStyle(Sourdough.Colors.action)
            .sourdoughTextStyle(.subhead)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .overlay(
                RoundedRectangle(cornerRadius: Sourdough.Radius.card, style: .continuous)
                    .stroke(Sourdough.Colors.action, style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
        }
        .buttonStyle(.plain)
    }

    private var regenerateButton: some View {
        Button {
            isEditingDetectedIngredients = false
            startGeneration()
        } label: {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                Ph.arrowClockwise.bold.frame(width: 16, height: 16)
                Text("Regenerate")
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

    // MARK: - Generation error

    private func generationErrorView(_ error: Error) -> some View {
        let recipeErr = error as? RecipeGenerationError
        let isLimit: Bool = { if case .limitExhausted = recipeErr { return true }; return false }()

        return VStack(spacing: Sourdough.Spacing.rowInternals) {
            Spacer()
            (isLimit ? Ph.warning.regular : Ph.wifiSlash.regular)
                .frame(width: 48, height: 48)
                .foregroundStyle(Sourdough.Colors.mutedInk)
            Text(isLimit ? "Daily limit reached" : "Our chef is busy")
                .sourdoughTextStyle(.title2, color: Sourdough.Colors.ink)
            Text(isLimit
                 ? "You've used all 5 recipe generations for today. They reset at midnight."
                 : "Couldn't put a recipe together. Check your connection and try again.")
                .multilineTextAlignment(.center)
                .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
                .padding(.horizontal, Sourdough.Spacing.betweenBlocks)

            Spacer()

            VStack(spacing: Sourdough.Spacing.insideChip) {
                if !isLimit {
                    Button { startGeneration() } label: {
                        Text("Try again")
                            .foregroundStyle(Sourdough.Colors.onAction)
                            .sourdoughTextStyle(.rowTitle)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Sourdough.Colors.action)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Button {
                        generationError = nil
                        if resultRecipe != nil {
                            isEditingDetectedIngredients = true
                            phase = .result
                        } else {
                            phase = .review
                        }
                    } label: {
                        Text("Edit ingredients")
                            .sourdoughTextStyle(.subhead, color: Sourdough.Colors.mutedInk)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button { onFinished() } label: {
                        Text("Done")
                            .foregroundStyle(Sourdough.Colors.onAction)
                            .sourdoughTextStyle(.rowTitle)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Sourdough.Colors.action)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
            .padding(.bottom, Sourdough.Spacing.screenMargin)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Sourdough.Colors.canvas)
    }

    // MARK: - Actions

    private func handleCapture(_ image: UIImage) {
        phase = .identifying
        identifyTask?.cancel()
        identifyTask = Task { await runIdentification(image) }
    }

    private func runIdentification(_ image: UIImage) async {
        guard let data = compress(image) else {
            showScanFailedAlert = true
            return
        }
        do {
            let scanned = try await scanner.identifyItems(in: data)
            guard !Task.isCancelled else { return }
            ingredients = scanned.map {
                let parsed = UnitMeasurement.parse(from: $0.estimatedQuantity)
                return SnapChefIngredient(
                    name: $0.name.lowercased(),
                    amount: parsed.value,
                    unit: parsed.unit,
                    lowConfidence: $0.confidence < 0.6
                )
            }
            if ingredients.isEmpty {
                phase = .review
            } else {
                await startGeneration()
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            showScanFailedAlert = true
        }
    }

    /// Formats each ingredient as `"name (amount)"` when an amount is present, matching
    /// `GenerateView.runGeneration`'s convention — read fresh at every call so an in-place edit to
    /// `ingredients` (via the result screen's review section) is picked up by the next Regenerate.
    private func ingredientNames() -> [String] {
        ingredients.compactMap { item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let quantity = displayQuantity(item)
            return quantity.isEmpty ? name : "\(name) (\(quantity))"
        }
    }

    private func displayQuantity(_ item: SnapChefIngredient) -> String {
        let amount = item.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !amount.isEmpty else { return "" }
        let unitLabel = item.unit.chipLabel
        return unitLabel.isEmpty ? amount : "\(amount) \(unitLabel)"
    }

    @MainActor
    private func startGeneration() {
        generationError = nil
        phase = .loading

        let options = GenerationOptions(snapChefProfile: session)
        let names = ingredientNames()

        generationTask?.cancel()
        generationTask = Task {
            do {
                let out = try await recipeGenerator.snapChefRecipe(for: names, options: options)
                guard !Task.isCancelled else { return }
                resultRecipe = out.recipe
                isEditingDetectedIngredients = false
                withAnimation { phase = .result }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                generationError = error
            }
        }
    }

    /// ~1024px long edge, JPEG 0.5 — same as the pantry Photo Scan pipeline.
    private func compress(_ image: UIImage) -> Data? {
        let maxEdge: CGFloat = 1024
        let scale = min(1, maxEdge / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.5)
    }
}

// MARK: - Options from profile

extension GenerationOptions {
    /// Snap Chef builds options straight from the saved profile — no cook-time / cuisine / calorie
    /// constraints the user didn't ask for. Diet, restrictions and allergies carry through as the
    /// prompt's hard constraints.
    @MainActor
    init(snapChefProfile session: AppSession) {
        var allergies = session.currentUserAllergies.map(\.rawValue).sorted()
        let custom = session.currentUserCustomAllergy.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { allergies.append(custom) }

        self.init(
            dietType: session.currentUserDietaryPreference,
            dietaryRestrictions: session.currentUserDietaryRestrictions,
            allergies: allergies,
            maxTimeMinutes: 60,      // prompt ignores >= 60 — no cook-time cap
            targetCalories: nil,
            cuisine: nil,
            skillLevel: session.currentUserCookingSkillLevel,
            priorityIngredients: []
        )
    }
}
