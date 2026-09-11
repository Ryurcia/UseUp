import SwiftUI
import VisionKit
import PhosphorSwift

/// Focused barcode-only capture, feeding directly into Photo Scan's running batch queue rather
/// than a separate dead-end flow. Reuses VisionKit's live-highlighting scanner — meaningfully
/// faster/more accurate for "I know this is a barcode" than the main shutter's snap-a-photo-then-
/// detect approach. Deliberately does not recreate the old single-item BarcodeScannerSheet's OCR
/// expiration-capture phase — expiration is already editable in BatchScanReviewView.
struct QuickBarcodeScannerView: View {
    let onResult: (OpenFoodFactsService.ProductInfo) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isLookingUp = false
    @State private var lookupError: String?

    var body: some View {
        ZStack {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerRepresentable(onScan: handleBarcode)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            Canvas { ctx, size in
                let w: CGFloat = 280, h: CGFloat = 120
                let rect = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
                let path = Path(roundedRect: rect, cornerRadius: 12)
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.55)))
                ctx.blendMode = .clear
                ctx.fill(path, with: .color(.white))
                ctx.blendMode = .normal
                ctx.stroke(path, with: .color(.white), lineWidth: 2)
            }
            .ignoresSafeArea()
            .opacity(isLookingUp ? 0.4 : 1)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Ph.x.bold
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Sourdough.Spacing.screenMargin)
                .padding(.top, Sourdough.Spacing.rowInternals)

                Spacer()

                bottomContent
                    .padding(.bottom, Sourdough.Spacing.betweenBlocks)
            }
        }
        .background(Color.black)
    }

    @ViewBuilder
    private var bottomContent: some View {
        if isLookingUp {
            VStack(spacing: Sourdough.Spacing.rowInternals) {
                ProgressView().tint(.white)
                Text("Fetching product info…")
                    .foregroundStyle(.white)
                    .font(.system(size: 15))
            }
        } else if let lookupError {
            VStack(spacing: Sourdough.Spacing.rowInternals) {
                Text(lookupError)
                    .foregroundStyle(.white)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Sourdough.Spacing.betweenBlocks)
                Button("Try Again") { self.lookupError = nil }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Sourdough.Spacing.rowInternals)
                    .padding(.vertical, Sourdough.Spacing.iconToLabel)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())
            }
        } else {
            VStack(spacing: Sourdough.Spacing.insideChip) {
                Text("Aim at a barcode to scan")
                    .foregroundStyle(.white.opacity(0.85))
                    .font(.system(size: 15))
                Text("It'll be added straight to your capture queue.")
                    .foregroundStyle(.white.opacity(0.55))
                    .font(.system(size: 12))
            }
        }
    }

    private func handleBarcode(_ barcode: String) {
        guard !isLookingUp, lookupError == nil else { return }
        isLookingUp = true
        Task {
            do {
                let info = try await OpenFoodFactsService.lookup(barcode: barcode)
                await MainActor.run {
                    dismiss()
                    onResult(info)
                }
            } catch {
                await MainActor.run {
                    isLookingUp = false
                    lookupError = "Product not found. Try again or use Photo Scan instead."
                }
            }
        }
    }
}

// MARK: - DataScannerRepresentable

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean8, .ean13, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        DispatchQueue.main.async { try? vc.startScanning() }
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard case .barcode(let item) = addedItems.first,
                  let payload = item.payloadStringValue else { return }
            onScan(payload)
        }
    }
}
