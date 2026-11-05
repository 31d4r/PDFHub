import Foundation
import PDFKit

public protocol PDFFileWriterServiceProtocol: Sendable {
    func savePDFDocument(
        _ document: PDFDocument,
        to url: URL
    ) throws
    func savePDFDocuments(
        _ pages: [SplitPage],
        to directory: URL
    ) -> SaveResult
}

public struct PDFFileWriterService: PDFFileWriterServiceProtocol {
    private let fileIOService: FileIOServiceProtocol

    public init(fileIOService: FileIOServiceProtocol = FileIOService()) {
        self.fileIOService = fileIOService
    }

    public func savePDFDocument(
        _ document: PDFDocument,
        to url: URL
    ) throws {
        guard let data = document.dataRepresentation() else {
            throw PDFFileWriterError.failedToCreateData
        }
        try fileIOService.write(data: data, to: url)
    }

    public func savePDFDocuments(
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
    public func uniqueURL(
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

public struct SaveResult: Equatable {
    public let successCount: Int
    public let failureCount: Int
    public let errors: [Error]

    public init(successCount: Int, failureCount: Int, errors: [Error]) {
        self.successCount = successCount
        self.failureCount = failureCount
        self.errors = errors
    }

    public var isCompleteSuccess: Bool {
        failureCount == 0
    }

    public var isCompleteFailure: Bool {
        successCount == 0
    }

    public static func == (
        lhs: SaveResult,
        rhs: SaveResult
    ) -> Bool {
        lhs.successCount == rhs.successCount
            && lhs.failureCount == rhs.failureCount
            && lhs.errors.count == rhs.errors.count
    }
}

public enum PDFFileWriterError: LocalizedError {
    case failedToCreateData

    public var errorDescription: String? {
        switch self {
        case .failedToCreateData:
            return String(localized: "The PDF data could not be created.", bundle: .module)
        }
    }
}
