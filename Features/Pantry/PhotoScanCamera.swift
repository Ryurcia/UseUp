import SwiftUI
import AVFoundation

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
