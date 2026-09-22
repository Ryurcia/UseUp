import SwiftUI
import AVFoundation
import VisionKit

/// Live rear-camera preview with a shutter + torch, shared by the pantry Photo Scan flow
/// (`PhotoScanCaptureView`) and Snap Chef (`SnapChefFlow`). Flip `captureRequested` to take a
/// photo; the JPEG-decoded `UIImage` comes back via `onCapture`.
struct PhotoScanCameraRepresentable: UIViewControllerRepresentable {
    @Binding var captureRequested: Bool
    var torchOn: Bool
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PhotoScanCameraViewController {
        let vc = PhotoScanCameraViewController()
        vc.onCapture = onCapture
        return vc
    }

    func updateUIViewController(_ uiViewController: PhotoScanCameraViewController, context: Context) {
        if captureRequested {
            uiViewController.capturePhoto()
            DispatchQueue.main.async { captureRequested = false }
        }
        uiViewController.setTorch(torchOn)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator {}
}

final class PhotoScanCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onCapture: ((UIImage) -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?

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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning() }
    }

    private func setupSession() {
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        self.device = device
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
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func setTorch(_ on: Bool) {
        guard let device, device.hasTorch, device.isTorchAvailable else { return }
        let desiredMode: AVCaptureDevice.TorchMode = on ? .on : .off
        guard device.torchMode != desiredMode else { return }
        try? device.lockForConfiguration()
        device.torchMode = desiredMode
        device.unlockForConfiguration()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.onCapture?(image) }
    }
}

// MARK: - Barcode scanner (VisionKit)

/// Live barcode detection via VisionKit's `DataScannerViewController` — meaningfully faster/more
/// accurate for "I know this is a barcode" than snap-a-photo-then-detect. Shared by Photo Scan's
/// Barcode mode toggle; `onScan` fires once per newly-recognized barcode payload.
struct DataScannerRepresentable: UIViewControllerRepresentable {
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
