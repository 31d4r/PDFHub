import PDFKit
import SwiftUI

struct PDFKitView: NSViewRepresentable {
    let url: URL?
    @Binding var rotationAngle: RotationAngle

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
            pdfView.document = PDFDocument(url: url)
            context.coordinator.loadedURL = url
        }

        applyRotation(
            to: pdfView.document,
            angle: rotationAngle
        )

        return pdfView
    }

    func updateNSView(
        _ nsView: PDFView,
        context: Context
    ) {
        if let url {
            if context.coordinator.loadedURL != url {
                nsView.document = PDFDocument(url: url)
                context.coordinator.loadedURL = url
            }
        } else if context.coordinator.loadedURL != nil {
            nsView.document = nil
            context.coordinator.loadedURL = nil
        }

        applyRotation(
            to: nsView.document,
            angle: rotationAngle
        )
    }

    private func applyRotation(
        to document: PDFDocument?,
        angle: RotationAngle
    ) {
        guard let document else { return }

        for pageIndex in 0 ..< document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            page.rotation = angle.degrees
        }
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}
