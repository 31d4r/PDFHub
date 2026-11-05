import Foundation
import PDFKit

protocol PDFFileWriterServiceProtocol: Sendable {
    func savePDFDocument(
        _ document: PDFDocument,
        to url: URL
    ) throws
    func savePDFDocuments(
        _ pages: [SplitPage],
        to directory: URL
    ) -> SaveResult
}

struct PDFFileWriterService: PDFFileWriterServiceProtocol {
    private let fileIOService: FileIOServiceProtocol

    init(fileIOService: FileIOServiceProtocol = FileIOService()) {
        self.fileIOService = fileIOService
    }

    func savePDFDocument(
        _ document: PDFDocument,
        to url: URL
    ) throws {
        guard let data = document.dataRepresentation() else {
            throw PDFFileWriterError.failedToCreateData
        }
        try fileIOService.write(data: data, to: url)
    }

    func savePDFDocuments(
        _ pages: [SplitPage],
        to directory: URL
    ) -> SaveResult {
        var successCount = 0
        var failureCount = 0
        var errors: [Error] = []
        var usedNames: Set<String> = []

        for page in pages {
            let fileURL = uniqueURL(for: page.fileName, in: directory, excluding: usedNames)
            usedNames.insert(fileURL.lastPathComponent)

            do {
                try savePDFDocument(page.document, to: fileURL)
                successCount += 1
            } catch {
                failureCount += 1
                errors.append(error)
            }
        }

        return SaveResult(
            successCount: successCount,
            failureCount: failureCount,
            errors: errors
        )
    }

    /// Returns `directory/fileName`, or `name (2).pdf`, `name (3).pdf`, … when that
    /// name already exists on disk or was used earlier in the same batch.
    func uniqueURL(
        for fileName: String,
        in directory: URL,
        excluding usedNames: Set<String> = []
    ) -> URL {
        let base = (fileName as NSString).deletingPathExtension
        let pathExtension = (fileName as NSString).pathExtension
        var candidate = fileName
        var counter = 2

        while usedNames.contains(candidate)
            || fileIOService.fileExists(at: directory.appendingPathComponent(candidate)) {
            candidate = pathExtension.isEmpty
                ? "\(base) (\(counter))"
                : "\(base) (\(counter)).\(pathExtension)"
            counter += 1
        }

        return directory.appendingPathComponent(candidate)
    }
}

struct SaveResult: Equatable {
    let successCount: Int
    let failureCount: Int
    let errors: [Error]

    var isCompleteSuccess: Bool {
        failureCount == 0
    }

    var isCompleteFailure: Bool {
        successCount == 0
    }

    static func == (
        lhs: SaveResult,
        rhs: SaveResult
    ) -> Bool {
        lhs.successCount == rhs.successCount
            && lhs.failureCount == rhs.failureCount
            && lhs.errors.count == rhs.errors.count
    }
}

enum PDFFileWriterError: LocalizedError {
    case failedToCreateData

    var errorDescription: String? {
        switch self {
        case .failedToCreateData:
            return "The PDF data could not be created."
        }
    }
}
