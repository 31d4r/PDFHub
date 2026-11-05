#if os(iOS)
import AsyncReactor
import PhotosUI
import SwiftUI

/// What a new scan starts from.
struct ScanRequest: Identifiable {
    enum Source {
        /// The document camera.
        case camera
        /// Photos already taken, in the order they were picked.
        case photos([PhotosPickerItem])
        /// File URLs supplied by UI tests (no Photos picker).
        case fixture([URL])
    }

    let id = UUID()
    let source: Source
}

/// One scan from start to saved PDF: the camera or the picked photos first, then the review.
/// `onSaved` gets the PDF so it can join the workspace.
struct ScanFlowView: View {
    let request: ScanRequest
    let onSaved: (URL) -> Void

    var body: some View {
        ReactorView(ScanReactor()) {
            ScanFlowContent(request: request, onSaved: onSaved)
        }
    }
}

private struct ScanFlowContent: View {
    let request: ScanRequest
    let onSaved: (URL) -> Void

    @EnvironmentObject private var reactor: ScanReactor
    @Environment(\.dismiss) private var dismiss
    @State private var hasCaptured = false
    @State private var isLoadingPhotos = false

    var body: some View {
        Group {
            if showsCamera {
                DocumentCameraView { images in
                    guard !images.isEmpty else { return dismiss() }
                    hasCaptured = true
                    Task { await reactor.action(.addCaptures(images)) }
                } onCancel: {
                    dismiss()
                }
                .ignoresSafeArea()
            } else {
                ScanReviewView(isLoadingPhotos: isLoadingPhotos) {
                    dismiss()
                }
            }
        }
        .task {
            switch request.source {
            case .photos(let items):
                await addPhotos(items)
            case .fixture(let urls):
                await reactor.action(.addPhotos(urls))
            case .camera:
                break
            }
        }
        .onChange(of: reactor.state.savedURL) { _, url in
            if let url { onSaved(url) }
        }
    }

    private var showsCamera: Bool {
        guard case .camera = request.source else { return false }
        return !hasCaptured
    }

    private func addPhotos(_ items: [PhotosPickerItem]) async {
        isLoadingPhotos = true
        let result = await PhotoLibraryImporter.load(items)
        isLoadingPhotos = false
        await reactor.action(.addPhotos(result.urls))
        ScanPhotoCleanup.remove(result.urls)
        if result.failedCount > 0 {
            reactor.action(.showError(DesignSystem.Mobile.photosFailed(result.failedCount)))
        }
    }
}

/// Deletes the copies of picked photos once their pages are stored.
enum ScanPhotoCleanup {
    static func remove(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }
}
#endif
