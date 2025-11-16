import Foundation
import PDFKit

protocol PDFFileWriterServiceProtocol {
    func savePDFDocument(_ document: PDFDocument, to url: URL) throws
    func savePDFDocuments(_ documents: [PDFDocument], to directory: URL, fileNamePrefix: String) -> SaveResult
}

struct PDFFileWriterService: PDFFileWriterServiceProtocol {
    private let fileIOService: FileIOServiceProtocol
    
    init(fileIOService: FileIOServiceProtocol = FileIOService()) {
        self.fileIOService = fileIOService
    }
    
    func savePDFDocument(_ document: PDFDocument, to url: URL) throws {
        guard let data = document.dataRepresentation() else {
            throw PDFFileWriterError.failedToCreateData
        }
        try fileIOService.write(data: data, to: url)
    }
    
    func savePDFDocuments(_ documents: [PDFDocument], to directory: URL, fileNamePrefix: String) -> SaveResult {
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

struct SaveResult {
    let successCount: Int
    let failureCount: Int
    let errors: [Error]
    
    var isCompleteSuccess: Bool {
        failureCount == 0
    }
    
    var isCompleteFailure: Bool {
        successCount == 0
    }
    
    var message: String {
        if isCompleteSuccess {
            return "Successfully saved \(successCount) PDF file\(successCount == 1 ? "" : "s")"
        } else if isCompleteFailure {
            return "Failed to save any PDF files"
        } else {
            return "Partially successful: Saved \(successCount) file\(successCount == 1 ? "" : "s"), failed to save \(failureCount) file\(failureCount == 1 ? "" : "s")"
        }
    }
}

enum PDFFileWriterError: Error {
    case failedToCreateData
}

