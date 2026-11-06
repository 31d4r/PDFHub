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
    /// When `recognizeText` is true, Vision adds a searchable text layer.
    func convertImages(
        urls: [URL],
        rotations: [RotationAngle],
        to destination: URL,
        recognizeText: Bool
    ) async -> ExportAlert
    /// Saves PDFs and images as one PDF, in the given order.
    func combine(sources: [ExportSource], to destination: URL) async -> ExportAlert
    /// Saves every page of the PDFs, and every image, as its own PDF in `directory`.
    func split(sources: [ExportSource], into directory: URL) async -> ExportAlert
    /// Saves the chosen pages as one file: a new PDF, or the first chosen page as an image.
    func exportPages(_ source: PageExportSource, as format: PageExportFormat, to destination: URL) async -> ExportAlert
    /// Saves each chosen page of each PDF as its own image in `directory`.
    func exportPageImages(_ sources: [PageExportSource], as format: PageExportFormat, into directory: URL) async -> ExportAlert
}

struct ExportService: ExportServiceProtocol {
    private let pdfService: any PDFServiceProtocol
    private let imageService: any ImageServiceProtocol
    private let writer: any PDFFileWriterServiceProtocol
    private let fileIOService: any FileIOServiceProtocol
    private let pageExporter = PDFPageExporter()

    init(
        pdfService: any PDFServiceProtocol = PDFService(),
        imageService: any ImageServiceProtocol = ImageService(),
        writer: any PDFFileWriterServiceProtocol = PDFFileWriterService(),
        fileIOService: any FileIOServiceProtocol = FileIOService()
    ) {
        self.pdfService = pdfService
        self.imageService = imageService
        self.writer = writer
        self.fileIOService = fileIOService
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
    func convertImages(
        urls: [URL],
        rotations: [RotationAngle],
        to destination: URL,
        recognizeText: Bool
    ) async -> ExportAlert {
        let result = await imageService.convertImagesToPDF(
            imageUrls: urls,
            rotations: rotations,
            recognizeText: recognizeText
        )

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

    // MARK: - Pages

    @concurrent
    func exportPages(_ source: PageExportSource, as format: PageExportFormat, to destination: URL) async -> ExportAlert {
        do {
            switch format {
            case .pdf:
                let document = try pageExporter.extractPDF(source)
                guard !Task.isCancelled else { return .cancelled }
                try writer.savePDFDocument(document, to: destination)
            case .png, .jpeg:
                let prepared = try pageExporter.prepare(source)
                let (index, page) = prepared.pages[0]
                guard let data = pageExporter.imageData(for: page, format: format) else {
                    throw PageExportError.renderFailed(source.url, page: index)
                }
                guard !Task.isCancelled else { return .cancelled }
                try fileIOService.write(data: data, to: destination)
            }
            return ExportAlert(
                message: DesignSystem.Alerts.pagesSaved(fileName: destination.lastPathComponent),
                isSuccess: true,
                output: destination,
                sharedFiles: [destination]
            )
        } catch let error as PageExportError {
            return ExportAlert(message: DesignSystem.Alerts.pageExportFailed(error), isSuccess: false)
        } catch {
            return ExportAlert(
                message: DesignSystem.Alerts.failedToSavePages(error.localizedDescription),
                isSuccess: false
            )
        }
    }

    @concurrent
    func exportPageImages(_ sources: [PageExportSource], as format: PageExportFormat, into directory: URL) async -> ExportAlert {
        let names = PDFFileWriterService(fileIOService: fileIOService)
        var saved: [URL] = []
        var failureCount = 0
        var skippedURLs: [URL] = []
        var firstError: PageExportError?
        var usedNames: Set<String> = []

        for source in sources {
            if Task.isCancelled { break }
            let prepared: PDFPageExporter.PreparedPages
            do throws(PageExportError) {
                prepared = try pageExporter.prepare(source)
            } catch {
                skippedURLs.append(source.url)
                firstError = firstError ?? error
                continue
            }

            for (index, page) in prepared.pages {
                if Task.isCancelled { break }
                // Each page's bitmap and encoder buffers go as soon as it's written.
                autoreleasepool {
                    guard let data = pageExporter.imageData(for: page, format: format) else {
                        failureCount += 1
                        return
                    }
                    let fileName = PDFPageExporter.imageFileName(sourceURL: source.url, pageIndex: index, format: format)
                    let url = names.uniqueURL(for: fileName, in: directory, excluding: usedNames)
                    usedNames.insert(url.lastPathComponent)
                    do {
                        try fileIOService.write(data: data, to: url)
                        saved.append(url)
                    } catch {
                        failureCount += 1
                    }
                }
            }
        }

        if Task.isCancelled && saved.isEmpty { return .cancelled }

        guard !saved.isEmpty else {
            let message = failureCount == 0
                ? firstError.map(DesignSystem.Alerts.pageExportFailed) ?? DesignSystem.Alerts.failedToSaveAnyImages
                : DesignSystem.Alerts.failedToSaveAnyImages
            let skippedNote = sources.count > 1 ? skippedURLs : []
            return ExportAlert(message: DesignSystem.Alerts.message(message, skipped: skippedNote), isSuccess: false)
        }

        let summary = failureCount == 0
            ? DesignSystem.Alerts.imagesSaved(saved.count)
            : DesignSystem.Alerts.partialSaveSuccess(successCount: saved.count, failureCount: failureCount)
        return ExportAlert(
            message: DesignSystem.Alerts.message(summary, skipped: skippedURLs),
            isSuccess: true,
            output: directory,
            sharedFiles: saved
        )
    }
}
