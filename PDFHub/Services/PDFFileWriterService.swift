import Foundation
import PDFKit

protocol PDFFileWriterServiceProtocol {
    func savePDFDocument(
        _ document: PDFDocument,
        to url: URL
    ) throws
    func savePDFDocuments(
        _ documents: [PDFDocument],
        to directory: URL,
        fileNamePrefix: String
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
        _ documents: [PDFDocument],
        to directory: URL,
        fileNamePrefix: String
    ) -> SaveResult {
        var successCount = 0
        var failureCount = 0
        var errors: [Error] = []

        for (index, document) in documents.enumerated() {
            let fileName = "\(fileNamePrefix)_\(index).pdf"
            let fileURL = directory.appendingPathComponent(fileName)

            do {
                try savePDFDocument(document, to: fileURL)
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

enum PDFFileWriterError: Error {
    case failedToCreateData
}
