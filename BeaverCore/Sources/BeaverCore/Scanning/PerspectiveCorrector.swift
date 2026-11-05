import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Turns a page photographed at an angle into a flat, upright rectangle.
public enum PerspectiveCorrector {
    /// The part of `image` inside `quad`, stretched to `quad.outputSize`, with its origin at zero.
    /// The quad's top left ends up at the top left of the result.
    public static func correct(_ image: CIImage, quad: DocumentQuad) -> CIImage {
        let extent = image.extent
        let origin = image.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
        let size = quad.outputSize(in: extent.size)
        guard size.width >= 1, size.height >= 1 else { return origin }
        guard quad != .fullImage else { return origin.cropped(to: CGRect(origin: .zero, size: extent.size)) }

        let points = quad.points(in: extent.size)
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = origin
        filter.topLeft = points[0]
        filter.topRight = points[1]
        filter.bottomRight = points[2]
        filter.bottomLeft = points[3]
        filter.crop = true
        guard let corrected = filter.outputImage, !corrected.extent.isEmpty else { return origin }

        // Core Image picks its own size; scale to the page's measured edges so the result
        // doesn't depend on that choice.
        let flat = corrected.extent
        let scaled = corrected
            .transformed(by: CGAffineTransform(translationX: -flat.minX, y: -flat.minY))
            .transformed(by: CGAffineTransform(scaleX: size.width / flat.width, y: size.height / flat.height))
        return scaled.cropped(to: CGRect(origin: .zero, size: size))
    }
}
