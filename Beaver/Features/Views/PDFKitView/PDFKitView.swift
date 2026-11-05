import BeaverCore
import PDFKit
import SwiftUI

struct PDFKitView: NSViewRepresentable {
    let url: URL?
    /// The user's file and page rotations, shown on top of each page's saved rotation.
    let rotation: PDFRotation

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(
        context: Context
    ) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        pdfView.displayDirection = .vertical

        if let url {
            context.coordinator.load(url, into: pdfView)
        }

        context.coordinator.apply(rotation, to: pdfView)

        return pdfView
    }

    func updateNSView(
        _ nsView: PDFView,
        context: Context
    ) {
        if let url {
            if context.coordinator.loadedURL != url {
                context.coordinator.load(url, into: nsView)
            }
        } else if context.coordinator.loadedURL != nil {
            context.coordinator.unload(from: nsView)
        }

        context.coordinator.apply(rotation, to: nsView)
    }

    @MainActor
    final class Coordinator {
        private(set) var loadedURL: URL?
        /// Rotation stored in each page when the document was opened.
        private var originalRotations: [Int] = []
        private var appliedRotation: PDFRotation?

        func load(_ url: URL, into pdfView: PDFView) {
            let document = PDFDocument(url: url)
            pdfView.document = document
            loadedURL = url
            appliedRotation = nil
            originalRotations = (0 ..< (document?.pageCount ?? 0)).map {
                document?.page(at: $0)?.rotation ?? 0
            }
        }

        func unload(from pdfView: PDFView) {
            pdfView.document = nil
            loadedURL = nil
            appliedRotation = nil
            originalRotations = []
        }

        /// Shows the user's rotations on top of each page's own rotation. Only touches
        /// the pages when the rotations change, so they never compound.
        func apply(_ rotation: PDFRotation, to pdfView: PDFView) {
            guard let document = pdfView.document, appliedRotation != rotation else { return }

            for (pageIndex, original) in originalRotations.enumerated() {
                document.page(at: pageIndex)?.rotation = rotation.degrees(forPage: pageIndex, savedRotation: original)
            }
            appliedRotation = rotation
        }
    }
}
