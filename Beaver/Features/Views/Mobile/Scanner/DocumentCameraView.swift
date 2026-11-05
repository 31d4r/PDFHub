#if os(iOS)
import AVFoundation
import SwiftUI
import UIKit
import VisionKit

/// The system document camera. It finds each page's edges live, takes the photo when the
/// page holds still, and hands back the pages already flattened.
struct DocumentCameraView: UIViewControllerRepresentable {
    let onFinish: ([CGImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camera = VNDocumentCameraViewController()
        camera.delegate = context.coordinator
        return camera
    }

    func updateUIViewController(_ camera: VNDocumentCameraViewController, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    /// VisionKit calls back on the main thread.
    @MainActor
    final class Coordinator: NSObject, @preconcurrency VNDocumentCameraViewControllerDelegate {
        var parent: DocumentCameraView

        init(parent: DocumentCameraView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0..<scan.pageCount).compactMap { Self.upright(scan.imageOfPage(at: $0)) }
            parent.onFinish(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onCancel()
        }

        /// The page as pixels the right way up, whatever way the phone was held.
        private static func upright(_ image: UIImage) -> CGImage? {
            if image.imageOrientation == .up, let cgImage = image.cgImage {
                return cgImage
            }
            let format = UIGraphicsImageRendererFormat()
            format.scale = image.scale
            format.opaque = true
            return UIGraphicsImageRenderer(size: image.size, format: format)
                .image { _ in image.draw(at: .zero) }
                .cgImage
        }
    }
}

/// Whether this device can scan with its camera, and if not, why.
@MainActor
enum ScanAvailability {
    static var isCameraScanSupported: Bool {
        VNDocumentCameraViewController.isSupported
    }

    /// Whether the camera was turned off for Beaver in Settings, so scanning would show nothing.
    static var isCameraDenied: Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .denied, .restricted: return true
        default: return false
        }
    }

    /// Why Scan Document is dimmed, or `nil` when it works.
    static var unavailableReason: String? {
        guard !isCameraScanSupported else { return nil }
        #if targetEnvironment(simulator)
        return DesignSystem.Scan.unavailableInSimulator
        #else
        return DesignSystem.Scan.unavailableOnDevice
        #endif
    }
}
#endif
