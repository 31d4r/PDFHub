import CoreGraphics
import ImageIO
import Vision

/// Finds the page in a photo with Vision.
public enum DocumentDetector {
    /// The page's corners in an upright `image`, or `nil` when no page stands out. Tries
    /// Vision's document segmentation first, then plain rectangle detection.
    public static func detect(in image: CGImage) async -> DocumentQuad? {
        segmentedDocument(in: image) ?? largestRectangle(in: image)
    }

    private static func segmentedDocument(in image: CGImage) -> DocumentQuad? {
        #if targetEnvironment(simulator)
        // The simulator runs the segmentation model without the Neural Engine and returns the
        // same wrong outline for every photo; rectangle detection still works there.
        return nil
        #else
        let request = VNDetectDocumentSegmentationRequest()
        guard let quad = quad(from: perform(request, on: image)) else { return nil }
        // Segmentation outlines the whole frame when nothing stands out; look for edges instead.
        return quad.area < Constants.wholeFrameArea ? quad : nil
        #endif
    }

    private static func largestRectangle(in image: CGImage) -> DocumentQuad? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = Constants.maximumRectangles
        request.minimumConfidence = Constants.minimumConfidence
        request.minimumAspectRatio = Constants.minimumAspectRatio
        request.minimumSize = Constants.minimumSize
        request.quadratureTolerance = Constants.quadratureTolerance
        let candidates = perform(request, on: image)
            .compactMap { quad(from: [$0]) }
            .filter(\.isConvex)
        return candidates.max { $0.area < $1.area }
    }

    private static func perform(_ request: VNImageBasedRequest, on image: CGImage) -> [VNRectangleObservation] {
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        return (request.results as? [VNRectangleObservation]) ?? []
    }

    private static func quad(from observations: [VNRectangleObservation]) -> DocumentQuad? {
        guard
            let observation = observations.first,
            let quad = DocumentQuad(unordered: [
                observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft
            ]),
            quad.isConvex,
            quad.area >= Constants.minimumArea
        else { return nil }
        return quad
    }
}

private enum Constants {
    static let maximumRectangles = 4
    static let minimumConfidence: VNConfidence = 0.6
    static let minimumAspectRatio: VNAspectRatio = 0.3
    static let minimumSize: Float = 0.2
    static let quadratureTolerance: VNDegrees = 30
    /// A smaller "page" is more likely a label or a screen in the background.
    static let minimumArea = 0.05
    /// An outline this close to the photo's edges is the photo, not a page in it.
    static let wholeFrameArea = 0.97
}
