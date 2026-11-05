import BeaverCore
import Foundation
@testable import Beaver

/// Records export calls and returns a fixed alert. When `isGated` is true each
/// call waits until `release()` so tests can observe the in-progress state.
final class MockExportService: ExportServiceProtocol, @unchecked Sendable {
    enum Call: Equatable {
        case merge(urls: [URL], rotations: [PDFRotation], destination: URL)
        case split(urls: [URL], rotations: [PDFRotation], directory: URL)
        case convert(urls: [URL], rotations: [RotationAngle], destination: URL)
    }

    private let lock = NSLock()
    private var recordedCalls: [Call] = []
    private let gate: AsyncStream<Void>
    private let gateContinuation: AsyncStream<Void>.Continuation
    private let isGated: Bool

    let result: ExportAlert

    init(
        result: ExportAlert = ExportAlert(message: "done", isSuccess: true),
        isGated: Bool = false
    ) {
        self.result = result
        self.isGated = isGated
        (gate, gateContinuation) = AsyncStream.makeStream()
    }

    var calls: [Call] {
        lock.withLock { recordedCalls }
    }

    func release() {
        gateContinuation.yield()
    }

    func mergePDFs(urls: [URL], rotations: [PDFRotation], to destination: URL) async -> ExportAlert {
        await record(.merge(urls: urls, rotations: rotations, destination: destination))
    }

    func splitPDFs(urls: [URL], rotations: [PDFRotation], into directory: URL) async -> ExportAlert {
        await record(.split(urls: urls, rotations: rotations, directory: directory))
    }

    func convertImages(urls: [URL], rotations: [RotationAngle], to destination: URL) async -> ExportAlert {
        await record(.convert(urls: urls, rotations: rotations, destination: destination))
    }

    private func record(_ call: Call) async -> ExportAlert {
        lock.withLock { recordedCalls.append(call) }
        if isGated {
            for await _ in gate { break }
        }
        return result
    }
}
