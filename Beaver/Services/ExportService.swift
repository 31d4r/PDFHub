import BeaverCore
import Foundation
import PDFKit

/// Runs the PDF work for an export (reading, merging, splitting, converting and
/// writing) away from the main actor. Only `Sendable` values cross the boundary:
/// URLs in, an `ExportAlert` out. `PDFDocument`s never leave this service.
protocol ExportServiceProtocol: Sendable {
    func mergePDFs(urls: [URL], rotations: [PDFRotation], to destination: URL) async -> ExportAlert
    func splitPDFs(urls: [URL], rotations: [PDFRotation], into directory: URL) async -> ExportAlert
    /// `rotations[i]` turns `urls[i]` clockwise before it becomes a page.
    func convertImages(urls: [URL], rotations: [RotationAngle], to destination: URL) async -> ExportAlert
    /// Saves PDFs and images as one PDF, in the given order.
    func combine(sources: [ExportSource], to destination: URL) async -> ExportAlert
    /// Saves every page of the PDFs, and every image, as its own PDF in `directory`.
    func split(sources: [ExportSource], into directory: URL) async -> ExportAlert
}

struct ExportService: ExportServiceProtocol {
    private let pdfService: any PDFServiceProtocol
    private let imageService: any ImageServiceProtocol
    private let writer: any PDFFileWriterServiceProtocol

    init(
        pdfService: any PDFServiceProtocol = PDFService(),
        imageService: any ImageServiceProtocol = ImageService(),
        writer: any PDFFileWriterServiceProtocol = PDFFileWriterService()
    ) {
        self.pdfService = pdfService
        self.imageService = imageService
        self.writer = writer
    }

    private var composer: DocumentComposer {
        DocumentComposer(pdfService: pdfService, imageService: imageService)
    }

    @concurrent
    func mergePDFs(urls: [URL], rotations: [PDFRotation], to destination: URL) async -> ExportAlert {
        let result = pdfService.mergePDFs(urls: urls, rotations: rotations)

        guard let document = result.document else {
            return ExportAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.failedToMergePDFs,
                    skipped: result.skippedURLs
                ),
                isSuccess: false
            )
        }

        guard !Task.isCancelled else { return .cancelled }

        do {
            try writer.savePDFDocument(document, to: destination)
            return ExportAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.mergedPDFSaved(fileName: destination.lastPathComponent),
                    skipped: result.skippedURLs
                ),
                isSuccess: true,
                output: destination
            )
        } catch {
            return ExportAlert(
                message: DesignSystem.Alerts.failedToSaveMergedPDF(error.localizedDescription),
                isSuccess: false
            )
        }
    }

    @concurrent
    func splitPDFs(urls: [URL], rotations: [PDFRotation], into directory: URL) async -> ExportAlert {
        let result = pdfService.splitPDF(urls: urls, rotations: rotations)

        guard !result.pages.isEmpty else {
            return ExportAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.noPagesFoundToSplit,
                    skipped: result.skippedURLs
                ),
                isSuccess: false
            )
        }

        guard !Task.isCancelled else { return .cancelled }

        let saveResult = writer.savePDFDocuments(result.pages, to: directory)
        return ExportAlert(
            message: DesignSystem.Alerts.message(
                DesignSystem.Alerts.message(for: saveResult),
                skipped: result.skippedURLs
            ),
            isSuccess: !saveResult.isCompleteFailure,
            output: saveResult.isCompleteFailure ? nil : directory
        )
    }

    @concurrent
    func convertImages(urls: [URL], rotations: [RotationAngle], to destination: URL) async -> ExportAlert {
        let result = imageService.convertImagesToPDF(imageUrls: urls, rotations: rotations)

        guard let document = result.document else {
            return ExportAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.failedToConvertImages,
                    skipped: result.skippedURLs
                ),
                isSuccess: false
            )
        }

        guard !Task.isCancelled else { return .cancelled }

        do {
            try writer.savePDFDocument(document, to: destination)
            return ExportAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.convertedImagesSuccess,
                    skipped: result.skippedURLs
                ),
                isSuccess: true,
                output: destination
            )
        } catch {
            return ExportAlert(
                message: DesignSystem.Alerts.failedToSaveConvertedPDF(error.localizedDescription),
                isSuccess: false
            )
        }
    }

    @concurrent
    func combine(sources: [ExportSource], to destination: URL) async -> ExportAlert {
        let result = composer.combine(sources)

        guard let document = result.document else {
            return ExportAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.failedToCombine,
                    skipped: result.skippedURLs
                ),
                isSuccess: false
            )
        }

        guard !Task.isCancelled else { return .cancelled }

        do {
            try writer.savePDFDocument(document, to: destination)
            return ExportAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.combinedPDFSaved(fileName: destination.lastPathComponent),
                    skipped: result.skippedURLs
                ),
                isSuccess: true,
                output: destination
            )
        } catch {
            return ExportAlert(
                message: DesignSystem.Alerts.failedToSaveCombinedPDF(error.localizedDescription),
                isSuccess: false
            )
        }
    }

    @concurrent
    func split(sources: [ExportSource], into directory: URL) async -> ExportAlert {
        let result = composer.split(sources)

        guard !result.pages.isEmpty else {
            return ExportAlert(
                message: DesignSystem.Alerts.message(
                    DesignSystem.Alerts.noPagesFoundToSplit,
                    skipped: result.skippedURLs
                ),
                isSuccess: false
            )
        }

        guard !Task.isCancelled else { return .cancelled }

        let saveResult = writer.savePDFDocuments(result.pages, to: directory)
        return ExportAlert(
            message: DesignSystem.Alerts.message(
                DesignSystem.Alerts.message(for: saveResult),
                skipped: result.skippedURLs
            ),
            isSuccess: !saveResult.isCompleteFailure,
            output: saveResult.isCompleteFailure ? nil : directory
        )
    }
}
