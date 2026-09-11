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
    @EnvironmentObject private var activityStore: UserActivityStore

    private let scanner: FoodPhotoIdentifying = SupabaseFoodPhotoScanner()

    enum Phase { case tips, camera, identifying, review, loading, result }

    @State private var phase: Phase
    @State private var ingredients: [SnapChefIngredient] = []
    @State private var confirmedNames: [String] = []
    @State private var resultRecipe: Recipe?
    @State private var pushedRecipe: Recipe?
    @State private var generationError: Error?
    @State private var freeRegensRemaining: Int?
    @State private var lastWasRegeneration = false

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
                onConfirm: { startGeneration(isRegeneration: false) },
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
                    heroCard(recipe)
                }
                .buttonStyle(.plain)

                regenerateButton

                Text("Tap the card for the full recipe, ingredients and steps.")
                    .sourdoughTextStyle(.caption, color: Sourdough.Colors.faintInk)
                    .frame(maxWidth: .infinity, alignment: .center)
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

    private func heroCard(_ recipe: Recipe) -> some View {
        OnDarkHeroCard(
            image: Image("AI_GEN"),
            title: recipe.title,
            meta: "\(recipe.macros.calories) cal · \(recipe.macros.proteinG)g protein · \(recipe.timeMinutes) min"
        ) {
            if !recipe.ingredientsUsed.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(recipe.ingredientsUsed.prefix(6), id: \.id) { ingredient in
                            Text(ingredient.name.capitalized)
                                .foregroundStyle(Sourdough.Colors.heroTitleOnDark)
                                .sourdoughTextStyle(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.bottom, Sourdough.Spacing.iconToLabel)
            }
        }
        .overlay(alignment: .topLeading) {
            AIGeneratedBadge().padding(Sourdough.Spacing.rowInternals)
        }
        .overlay(alignment: .topTrailing) {
            let isSaved = savedRecipesStore.isSaved(recipe)
            Button {
                if isSaved { savedRecipesStore.unsaveRecipe(recipe) }
                else { savedRecipesStore.saveGeneratedRecipe(recipe) }
            } label: {
                (isSaved ? Ph.bookmark.fill : Ph.bookmark.regular)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(isSaved ? Sourdough.Ramp.sageDark : Sourdough.Colors.heroTitleOnDark)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(Sourdough.Spacing.rowInternals)
        }
    }

    private var regenerateButton: some View {
        let free = freeRegensRemaining ?? 0
        let dailyLeft = max(0, 5 - activityStore.generationsToday)
        let canRegen = free >= 1 || dailyLeft >= 1
        let label: String = free >= 1
            ? "Re-roll · \(free) free left"
            : dailyLeft >= 1 ? "Re-roll · uses 1 of \(dailyLeft) today"
            : "Daily limit reached"

        return Button { startGeneration(isRegeneration: true) } label: {
            HStack(spacing: Sourdough.Spacing.insideChip) {
                Ph.arrowClockwise.bold.frame(width: 16, height: 16)
                Text(label)
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
        .disabled(!canRegen)
        .opacity(canRegen ? 1 : 0.5)
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
                    Button { startGeneration(isRegeneration: lastWasRegeneration) } label: {
                        Text("Try again")
                            .foregroundStyle(Sourdough.Colors.onAction)
                            .sourdoughTextStyle(.rowTitle)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Sourdough.Colors.action)
                            .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Button { generationError = nil; phase = .review } label: {
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
                SnapChefIngredient(name: $0.name.lowercased(), lowConfidence: $0.confidence < 0.6)
            }
            phase = .review
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            showScanFailedAlert = true
        }
    }

    @MainActor
    private func startGeneration(isRegeneration: Bool) {
        generationError = nil
        lastWasRegeneration = isRegeneration
        if !isRegeneration {
            confirmedNames = ingredients
                .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        phase = .loading

        let options = GenerationOptions(snapChefProfile: session)
        let names = confirmedNames

        generationTask?.cancel()
        generationTask = Task {
            do {
                let out = try await recipeGenerator.snapChefRecipe(
                    for: names,
                    options: options,
                    isRegeneration: isRegeneration
                )
                guard !Task.isCancelled else { return }
                resultRecipe = out.recipe
                freeRegensRemaining = out.freeRegensRemaining
                if out.countedAgainstDailyLimit {
                    activityStore.noteRecipeGeneratedRemotely()
                }
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
            priorityIngredients: [],
            diversifyIngredients: false
        )
    }
}
