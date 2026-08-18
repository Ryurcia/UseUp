import SwiftUI
import VisionKit
import Vision
import AVFoundation
import PhosphorSwift

// MARK: - Phase

private enum ScanPhase: Equatable {
    case barcode
    case loadingProduct
    case captureExpiration
    case processingPhoto
}

// MARK: - BarcodeScannerSheet

struct BarcodeScannerSheet: View {
    let onResult: (String, String?, Ingredient.Category?, Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var phase: ScanPhase = .barcode
    @State private var scannedProduct: OpenFoodFactsService.ProductInfo?
    @State private var captureRequested = false
    @State private var barcodeError: String?

    var body: some View {
        ZStack {
            cameraLayer
            dimOverlay
            controlsLayer
        }
        .background(Color.black)
    }

    // MARK: - Camera layer

    @ViewBuilder private var cameraLayer: some View {
        switch phase {
        case .barcode:
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerRepresentable(onScan: handleBarcode)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
        case .loadingProduct:
            Color.black.ignoresSafeArea()
        case .captureExpiration, .processingPhoto:
            ExpirationCaptureRepresentable(
                captureRequested: $captureRequested,
                onCapture: handlePhoto
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Dim overlay + guide box

    @ViewBuilder private var dimOverlay: some View {
        switch phase {
        case .barcode:
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
        case .captureExpiration:
            Canvas { ctx, size in
                let w: CGFloat = 300, h: CGFloat = 90
                let rect = CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
                let path = Path(roundedRect: rect, cornerRadius: 10)
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.55)))
                ctx.blendMode = .clear
                ctx.fill(path, with: .color(.white))
                ctx.blendMode = .normal
                ctx.stroke(path, with: .color(.white), lineWidth: 2)
            }
            .ignoresSafeArea()
        case .loadingProduct, .processingPhoto:
            Color.black.opacity(0.75).ignoresSafeArea()
        }
    }

    // MARK: - Controls layer

    private var controlsLayer: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Ph.xCircle.fill
                        .frame(width: 30, height: 30)
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
                .padding(.top, DS.Spacing.space6)
                .padding(.trailing, DS.Spacing.space5)
            }

            Spacer()

            phaseBottomContent
                .padding(.bottom, DS.Spacing.space10)
        }
    }

    @ViewBuilder private var phaseBottomContent: some View {
        switch phase {
        case .barcode:
            if let msg = barcodeError {
                VStack(spacing: DS.Spacing.space3) {
                    Text(msg)
                        .font(.custom("Satoshi Variable", size: 15))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.space8)
                    Button("Try Again") { barcodeError = nil }
                        .font(.custom("Satoshi Variable", size: 14).weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.space5)
                        .padding(.vertical, DS.Spacing.space2)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            } else {
                VStack(spacing: DS.Spacing.space2) {
                    Text("Aim at a barcode to scan")
                        .font(.custom("Satoshi Variable", size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Results may not always be accurate — review before adding.")
                        .font(.custom("Satoshi Variable", size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.space8)
                }
            }

        case .loadingProduct:
            VStack(spacing: DS.Spacing.space3) {
                ProgressView().tint(.white)
                Text("Fetching product info…")
                    .font(.custom("Satoshi Variable", size: 15))
                    .foregroundStyle(.white)
            }

        case .captureExpiration:
            VStack(spacing: DS.Spacing.space5) {
                Text("Point at the expiration date")
                    .font(.custom("Satoshi Variable", size: 15))
                    .foregroundStyle(.white.opacity(0.85))

                HStack(spacing: DS.Spacing.space6) {
                    Button {
                        captureRequested = true
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.5), lineWidth: 3)
                                .frame(width: 76, height: 76)
                            Circle()
                                .fill(.white)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .buttonStyle(.plain)

                    Button("Skip") {
                        dismiss()
                        if let product = scannedProduct {
                            onResult(product.name, product.quantity, product.category, nil)
                        }
                    }
                    .font(.custom("Satoshi Variable", size: 15).weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                }

                Text("Date recognition may not always be accurate.\nPlease review and adjust if needed.")
                    .font(.custom("Satoshi Variable", size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.space8)
            }

        case .processingPhoto:
            VStack(spacing: DS.Spacing.space3) {
                ProgressView().tint(.white)
                Text("Reading expiration date…")
                    .font(.custom("Satoshi Variable", size: 15))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Handlers

    private func handleBarcode(_ barcode: String) {
        guard phase == .barcode else { return }
        phase = .loadingProduct
        barcodeError = nil
        Task {
            do {
                let info = try await OpenFoodFactsService.lookup(barcode: barcode)
                await MainActor.run {
                    scannedProduct = info
                    phase = .captureExpiration
                }
            } catch {
                await MainActor.run {
                    barcodeError = "Product not found. You can still enter details manually."
                    phase = .barcode
                }
            }
        }
    }

    private func handlePhoto(_ image: UIImage) {
        phase = .processingPhoto
        Task {
            let date = await recognizeExpirationDate(in: image)
            await MainActor.run {
                dismiss()
                if let product = scannedProduct {
                    onResult(product.name, product.quantity, product.category, date)
                }
            }
        }
    }
}

// MARK: - OCR

private func recognizeExpirationDate(in image: UIImage) async -> Date? {
    guard let cgImage = image.cgImage else { return nil }
    return await withCheckedContinuation { continuation in
        let request = VNRecognizeTextRequest { req, _ in
            let strings = (req.results as? [VNRecognizedTextObservation] ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
            continuation.resume(returning: parseExpirationDate(from: strings))
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
}

// MARK: - Date parsing

private func parseExpirationDate(from texts: [String]) -> Date? {
    let combined = texts.joined(separator: " ").uppercased()

    let months = ["JAN":1,"FEB":2,"MAR":3,"APR":4,"MAY":5,"JUN":6,
                  "JUL":7,"AUG":8,"SEP":9,"OCT":10,"NOV":11,"DEC":12]

    func fullYear(_ yy: Int) -> Int { yy < 50 ? 2000 + yy : 1900 + yy }
    func makeDate(year: Int, month: Int, day: Int = 1) -> Date? {
        var c = DateComponents(); c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c)
    }
    func nsRange() -> NSRange { NSRange(combined.startIndex..., in: combined) }
    func group(_ m: NSTextCheckingResult, _ i: Int) -> Int {
        Int((combined as NSString).substring(with: m.range(at: i))) ?? 0
    }

    // 1. MM/DD/YYYY or DD/MM/YYYY (slash or dash)
    if let rx = try? NSRegularExpression(pattern: #"\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b"#),
       let m = rx.firstMatch(in: combined, range: nsRange()) {
        let a = group(m, 1), b = group(m, 2), rawY = group(m, 3)
        let y = rawY < 100 ? fullYear(rawY) : rawY
        if a >= 1 && a <= 12 { return makeDate(year: y, month: a, day: b) }
        if b >= 1 && b <= 12 { return makeDate(year: y, month: b, day: a) }
    }

    // 2. MM/YYYY or MM/YY
    if let rx = try? NSRegularExpression(pattern: #"\b(\d{1,2})[/\-](\d{2,4})\b"#),
       let m = rx.firstMatch(in: combined, range: nsRange()) {
        let mo = group(m, 1), rawY = group(m, 2)
        let y = rawY < 100 ? fullYear(rawY) : rawY
        if mo >= 1 && mo <= 12 && y >= 2020 { return makeDate(year: y, month: mo) }
    }

    // 3. MON YYYY  (e.g. DEC 2025)
    for (abbr, mo) in months {
        if let r = combined.range(of: "\(abbr) (\\d{4})", options: .regularExpression),
           let y = Int(String(combined[r]).components(separatedBy: " ").last ?? "") {
            return makeDate(year: y, month: mo)
        }
    }

    // 4. DD MON YYYY  or  MON DD YYYY
    for (abbr, mo) in months {
        for pattern in ["\(abbr) (\\d{1,2}) (\\d{4})", "(\\d{1,2}) \(abbr) (\\d{4})"] {
            if let r = combined.range(of: pattern, options: .regularExpression) {
                let parts = String(combined[r]).components(separatedBy: CharacterSet.whitespaces)
                let nums = parts.compactMap(Int.init)
                if let y = nums.first(where: { $0 > 100 }),
                   let d = nums.first(where: { $0 <= 31 }) {
                    return makeDate(year: y, month: mo, day: d)
                }
            }
        }
    }

    // 5. YYYY-MM-DD (ISO)
    if let rx = try? NSRegularExpression(pattern: #"\b(\d{4})-(\d{2})-(\d{2})\b"#),
       let m = rx.firstMatch(in: combined, range: nsRange()) {
        return makeDate(year: group(m, 1), month: group(m, 2), day: group(m, 3))
    }

    return nil
}

// MARK: - DataScannerRepresentable (barcode phase)

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

// MARK: - ExpirationCaptureRepresentable (expiration phase)

private struct ExpirationCaptureRepresentable: UIViewControllerRepresentable {
    @Binding var captureRequested: Bool
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> ExpirationCameraViewController {
        let vc = ExpirationCameraViewController()
        vc.onCapture = onCapture
        return vc
    }

    func updateUIViewController(_ uiViewController: ExpirationCameraViewController, context: Context) {
        if captureRequested {
            uiViewController.capturePhoto()
            DispatchQueue.main.async { captureRequested = false }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator {}
}

private final class ExpirationCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onCapture: ((UIImage) -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?
            .compactMap { $0 as? AVCaptureVideoPreviewLayer }
            .first?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning() }
    }

    private func setupSession() {
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)

        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.onCapture?(image) }
    }
}
