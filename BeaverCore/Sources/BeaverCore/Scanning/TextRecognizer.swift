import CoreGraphics
import Foundation
import Vision

/// Words and lines Vision finds on a page, ready to become an invisible PDF text layer.
public struct RecognizedText: Sendable, Equatable {
    /// One selectable run of text and where it sits on the page.
    public struct Run: Sendable, Equatable {
        public let string: String
        /// Vision's unit square: origin at the bottom left, x right, y up.
        public let boundingBox: CGRect

        public init(string: String, boundingBox: CGRect) {
            self.string = string
            self.boundingBox = boundingBox
        }
    }

    public let runs: [Run]

    public init(runs: [Run]) {
        self.runs = runs
    }

    /// The runs joined with newlines, for Copy and VoiceOver.
    public var string: String {
        runs.map(\.string).joined(separator: "\n")
    }

    public var isEmpty: Bool { runs.isEmpty }
}

/// Reads text from a page image with Vision. Safe to call off the main actor.
///
/// Recognition runs on a dedicated serial queue so Swift Testing (and multi-page
/// saves) never block the cooperative thread pool with Vision's synchronous API.
public enum TextRecognizer {
    public enum Error: Swift.Error, Equatable {
        case cancelled
        case failed
    }

    /// Languages we prefer when the device supports them. Vision's accurate model
    /// currently lists English and German from this set; Bosnian / Croatian / Serbian
    /// Latin share the Latin script, so automatic language detection still helps when
    /// those locales aren't in `supportedRecognitionLanguages` yet.
    public static let preferredLanguages = ["en-US", "de-DE", "hr-HR", "bs", "sr-Latn", "sr"]

    /// Serialises Vision's blocking `perform` so concurrent callers can't starve the pool.
    private static let queue = DispatchQueue(label: "com.eldartutnjic.Beaver.text-recognizer", qos: .userInitiated)

    /// Languages this device can actually recognise, from `preferredLanguages`.
    public static func availableLanguages() -> [String] {
        let supported = Set(Self.supportedLanguages())
        let matched = preferredLanguages.filter { supported.contains($0) }
        return matched.isEmpty ? Array(supported).sorted() : matched
    }

    /// Recognises text in `image`. Reports progress from 0…1 and throws `Error.cancelled`
    /// when the surrounding task is cancelled.
    public static func recognize(
        in image: CGImage,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> RecognizedText {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let result = try Self.recognizeSync(in: image, progress: progress)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private static func supportedLanguages() -> [String] {
        (try? VNRecognizeTextRequest.supportedRecognitionLanguages(
            for: .accurate,
            revision: VNRecognizeTextRequest.currentRevision
        )) ?? []
    }

    private static func recognizeSync(
        in image: CGImage,
        progress: (@Sendable (Double) -> Void)?
    ) throws -> RecognizedText {
        if Task.isCancelled { throw Error.cancelled }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = availableLanguages()
        if #available(iOS 16.0, macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }
        request.progressHandler = { _, fraction, _ in
            progress?(Double(fraction))
        }

        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        do {
            try handler.perform([request])
        } catch is CancellationError {
            throw Error.cancelled
        } catch {
            if Task.isCancelled { throw Error.cancelled }
            throw Error.failed
        }
        if Task.isCancelled { throw Error.cancelled }

        let observations = request.results ?? []
        var runs: [RecognizedText.Run] = []
        for observation in observations {
            guard let top = observation.topCandidates(1).first else { continue }
            let words = wordRuns(in: top, observationBounds: observation.boundingBox)
            if words.isEmpty {
                let text = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                runs.append(.init(string: text, boundingBox: observation.boundingBox))
            } else {
                runs.append(contentsOf: words)
            }
        }
        progress?(1)
        return RecognizedText(runs: runs)
    }

    /// Splits a line into words so a PDF selection can sit on one word.
    private static func wordRuns(
        in candidate: VNRecognizedText,
        observationBounds: CGRect
    ) -> [RecognizedText.Run] {
        let full = candidate.string
        var runs: [RecognizedText.Run] = []
        full.enumerateSubstrings(in: full.startIndex..<full.endIndex, options: .byWords) { word, range, _, _ in
            guard let word, !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let box: CGRect
            if let matched = try? candidate.boundingBox(for: range)?.boundingBox {
                box = matched
            } else {
                box = observationBounds
            }
            runs.append(.init(string: word, boundingBox: box))
        }
        return runs
    }
}
