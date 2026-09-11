import SwiftUI
import AVFoundation
import PhotosUI
import PhosphorSwift

/// Batch grocery-haul capture: one camera session stays open across the whole session, each
/// shutter tap is identified async (barcode-first, falling back to AI vision via the
/// `scan-food-photo` edge function) and appended to a running queue, then "Review & Save" hands
/// the queue off to `BatchScanReviewView`.
struct PhotoScanCaptureView: View {
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var storageDefault: Ingredient.StorageLocation = .fridge
    @State private var items: [BatchScanItem] = []
    @State private var captureRequested = false
    @State private var navigateToReview = false
    @State private var lastCaptureToken: UUID?
    @State private var pendingRetryItem: BatchScanItem?
    @State private var retakeTargetItem: BatchScanItem?
    @State private var isTorchOn = false
    @State private var showBarcodeScanner = false
    @State private var showTipsReference = false
    @State private var showPhotosPicker = false
    @State private var selectedPhoto: PhotosPickerItem?

    /// Whether the tips + permission-priming screen stands in front of the camera. Resolved once
    /// when the view is created — not reactively — so ticking "Don't show this again" inside the
    /// tips screen only records the preference; the screen still dismisses only on Continue.
    /// Shows when tips aren't hidden, or (regardless) when camera access isn't granted yet, so a
    /// denied/undetermined user gets a recovery path instead of a black preview.
    @State private var showTips: Bool
    @State private var didPassTips = false

    private let foodPhotoScanner: FoodPhotoIdentifying = SupabaseFoodPhotoScanner()

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        let tipsHidden = UserDefaults.standard.bool(forKey: "hidePhotoScanTips")
        let cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        _showTips = State(initialValue: !tipsHidden || !cameraAuthorized)
    }

    var body: some View {
        if showTips && !didPassTips {
            PhotoScanTipsView(
                onContinue: { didPassTips = true },
                onCancel: {
                    dismiss()
                    onComplete()
                }
            )
        } else {
            cameraFlow
        }
    }

    private var cameraFlow: some View {
        NavigationStack {
            ZStack {
                PhotoScanCameraRepresentable(captureRequested: $captureRequested, torchOn: isTorchOn, onCapture: handleCapture)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    bottomControls
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToReview) {
                BatchScanReviewView(items: $items, onSaved: {
                    dismiss()
                    onComplete()
                }, onRetakeRequested: { item in
                    retakeTargetItem = item
                    navigateToReview = false
                })
            }
            .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        handleCapture(image)
                    }
                    selectedPhoto = nil
                }
            }
            .fullScreenCover(isPresented: $showBarcodeScanner) {
                QuickBarcodeScannerView { product in
                    items.append(BatchScanItem(offProduct: product, captureToken: UUID(), thumbnail: nil, sessionStorageDefault: storageDefault))
                }
            }
            .fullScreenCover(isPresented: $showTipsReference) {
                PhotoScanTipsView(
                    onContinue: { showTipsReference = false },
                    onCancel: { showTipsReference = false }
                )
            }
            .alert("Photo Couldn't Be Processed", isPresented: Binding(
                get: { pendingRetryItem != nil },
                set: { if !$0 { pendingRetryItem = nil } }
            ), presenting: pendingRetryItem) { item in
                Button("Cancel", role: .cancel) {
                    items.removeAll { $0.id == item.id }
                }
                Button("Retry") {
                    guard let thumbnail = item.thumbnail else { return }
                    Task { await runIdentification(on: thumbnail, replacing: item.id, captureToken: item.captureToken) }
                }
            } message: { item in
                Text(failureMessage(for: item.status))
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: Sourdough.Spacing.iconToLabel) {
            Button { dismiss() } label: {
                Ph.x.bold
                    .frame(width: 16, height: 16)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            storagePillControl

            Button { isTorchOn.toggle() } label: {
                Ph.lightbulb.regular
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(isTorchOn ? Color.white.opacity(0.3) : Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button { showTipsReference = true } label: {
                Ph.question.bold
                    .frame(width: 17, height: 17)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Sourdough.Spacing.screenMargin)
        .padding(.top, Sourdough.Spacing.rowInternals)
    }

    private var storagePillControl: some View {
        HStack(spacing: 4) {
            ForEach(Ingredient.StorageLocation.allCases) { loc in
                let isSelected = storageDefault == loc
                Button { storageDefault = loc } label: {
                    Text(loc.title)
                        .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? .black : .white.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.white : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.4))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        VStack(spacing: Sourdough.Spacing.rowInternals) {
            if let lastCaptureToken {
                HStack {
                    Spacer()
                    Button {
                        items.removeAll { $0.captureToken == lastCaptureToken }
                        self.lastCaptureToken = nil
                    } label: {
                        HStack(spacing: 4) {
                            Ph.arrowClockwise.regular.frame(width: 14, height: 14)
                            Text("Undo last capture").font(.system(size: 13))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
            }

            HStack {
                pillButton(icon: Ph.plus.bold, label: "Add manually") { navigateToReview = true }
                Spacer()
                pillButton(icon: Ph.barcode.bold, label: "Barcode") { showBarcodeScanner = true }
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)

            HStack {
                Button { showPhotosPicker = true } label: {
                    Ph.image.regular
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.black.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.input, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    captureRequested = true
                } label: {
                    ZStack {
                        Circle().stroke(.white.opacity(0.5), lineWidth: 3).frame(width: 76, height: 76)
                        Circle().fill(.white).frame(width: 64, height: 64)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Color.clear.frame(width: 48, height: 48)
            }
            .padding(.horizontal, Sourdough.Spacing.screenMargin)

            statusBar
        }
        .padding(.bottom, Sourdough.Spacing.betweenBlocks)
    }

    private func pillButton(icon: Image, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Sourdough.Spacing.iconToLabel) {
                icon.frame(width: 14, height: 14)
                Text(label).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Sourdough.Spacing.rowInternals)
            .frame(height: 44)
            .background(Color.black.opacity(0.4))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var statusBar: some View {
        if items.isEmpty {
            Text("Capture an item to continue")
                .sourdoughTextStyle(.rowTitle, color: .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
        } else {
            Button {
                navigateToReview = true
            } label: {
                Text("Review & Save (\(items.count))")
                    .sourdoughTextStyle(.rowTitle, color: .black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Sourdough.Radius.pill, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Sourdough.Spacing.screenMargin)
        }
    }

    // MARK: - Capture pipeline

    private func handleCapture(_ image: UIImage) {
        if let target = retakeTargetItem {
            retakeTargetItem = nil
            navigateToReview = true
            Task { await runIdentification(on: image, replacing: target.id, captureToken: target.captureToken) }
            return
        }

        let token = UUID()
        lastCaptureToken = token
        let placeholder = BatchScanItem(captureToken: token, thumbnail: image, name: "Identifying…", storageLocation: storageDefault, status: .processing)
        items.append(placeholder)
        Task { await runIdentification(on: image, replacing: placeholder.id, captureToken: token) }
    }

    /// Gemini-only identification pipeline, used both for a fresh capture and for retrying a
    /// failed one (on the same original photo). `id` is the queue entry being resolved — replaced
    /// in place with the final result(s), or with a `.failed` item that also pops the
    /// retry/cancel modal via `pendingRetryItem`. Barcode identification is a separate, explicit
    /// flow (`QuickBarcodeScannerView`, via the "Barcode" button) — regular captures never look
    /// for a barcode, so the two entry points can't be confused with each other.
    private func runIdentification(on image: UIImage, replacing id: UUID, captureToken: UUID) async {
        replacePlaceholder(id: id, with: [BatchScanItem(id: id, captureToken: captureToken, thumbnail: image, name: "Identifying…", storageLocation: storageDefault, status: .processing)])

        guard let compressed = compress(image) else {
            resolveFailure(id: id, captureToken: captureToken, thumbnail: image, message: "Couldn't process photo")
            return
        }

        do {
            let scanned = try await foodPhotoScanner.identifyItems(in: compressed)
            guard !scanned.isEmpty else {
                resolveFailure(id: id, captureToken: captureToken, thumbnail: image, message: "No items found")
                return
            }
            let resolved = scanned.map {
                BatchScanItem(scanned: $0, captureToken: captureToken, thumbnail: image, sessionStorageDefault: storageDefault)
            }
            replacePlaceholder(id: id, with: resolved)
        } catch {
            resolveFailure(id: id, captureToken: captureToken, thumbnail: image, message: error.localizedDescription)
        }
    }

    @MainActor
    private func resolveFailure(id: UUID, captureToken: UUID, thumbnail: UIImage, message: String) {
        let failed = BatchScanItem(id: id, captureToken: captureToken, thumbnail: thumbnail, name: "Tap to retry", storageLocation: storageDefault, status: .failed(message))
        replacePlaceholder(id: id, with: [failed])
        pendingRetryItem = failed
    }

    private func failureMessage(for status: BatchScanItem.Status) -> String {
        if case .failed(let message) = status { return message }
        return "Please try again."
    }

    @MainActor
    private func replacePlaceholder(id: UUID, with resolved: [BatchScanItem]) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            items.append(contentsOf: resolved)
            return
        }
        items.replaceSubrange(index...index, with: resolved)
    }

    /// ~1024px long edge, ~0.5 JPEG quality, per spec.
    private func compress(_ image: UIImage) -> Data? {
        let longEdge: CGFloat = 1024
        let size = image.size
        let scale = min(1, longEdge / max(size.width, size.height))
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: 0.5)
    }
}

// MARK: - Camera representable
//
// `PhotoScanCameraRepresentable` / `PhotoScanCameraViewController` now live in `PhotoScanCamera.swift`
// (shared with Snap Chef).
