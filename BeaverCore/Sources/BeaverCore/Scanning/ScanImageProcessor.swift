import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Flattens and cleans up photos of paper pages with Core Image, the same way on iOS and macOS.
/// The same input always gives the same pixels, so previews match the saved PDF.
public struct ScanImageProcessor: Sendable {
    /// Longest side kept from a camera photo: sharp text at A4 without huge files.
    public static let maximumPixelSize = 3200
    /// Paper is brighter than this after evening out the light; anything darker is ink.
    static let blackAndWhiteThreshold: Float = 0.78

    private let context: CIContext

    public init() {
        // Software rendering would be slow; the GPU result is the same each time for one device.
        context = CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) as Any,
            .cacheIntermediates: false
        ])
    }

    /// The page cut out along `quad`, flattened, filtered and turned clockwise by `rotation`.
    /// `nil` only when Core Image can't draw it.
    public func process(
        _ image: CGImage,
        quad: DocumentQuad = .fullImage,
        filter: ScanFilter,
        rotation: RotationAngle = .zero
    ) -> CGImage? {
        let flattened = PerspectiveCorrector.correct(CIImage(cgImage: image), quad: quad)
        let filtered = Self.apply(filter, to: flattened)
        guard let rendered = render(filtered) else { return nil }
        return ImageRotator.rotate(rendered, by: rotation)
    }

    /// A smaller copy for filter previews, so the strip of choices stays quick.
    public func preview(_ image: CGImage, quad: DocumentQuad, filter: ScanFilter, maxPixelSize: Int) -> CGImage? {
        let flattened = PerspectiveCorrector.correct(CIImage(cgImage: image), quad: quad)
        let longest = max(flattened.extent.width, flattened.extent.height)
        let scale = longest > 0 ? min(1, Double(maxPixelSize) / longest) : 1
        let small = flattened.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return render(Self.apply(filter, to: small))
    }

    func render(_ image: CIImage) -> CGImage? {
        let extent = image.extent.integral
        guard !extent.isEmpty, !extent.isInfinite else { return nil }
        return context.createCGImage(
            image,
            from: extent,
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )
    }

    // MARK: - Filters

    static func apply(_ filter: ScanFilter, to image: CIImage) -> CIImage {
        switch filter {
        case .original:
            return image
        case .enhanced:
            return enhanced(image)
        case .grayscale:
            return monochrome(enhanced(image))
        case .blackAndWhite:
            return blackAndWhite(image)
        }
    }

    /// Divides the page by an estimate of its lighting, which removes shadows and evens out
    /// colour casts, then lifts nearly white paper to white.
    static func enhanced(_ image: CIImage) -> CIImage {
        let divide = CIFilter.divideBlendMode()
        // Divide blend gives background ÷ input: the page over its lighting.
        divide.inputImage = background(of: image)
        divide.backgroundImage = image
        let evened = (divide.outputImage ?? image).cropped(to: image.extent)

        let curve = CIFilter.toneCurve()
        curve.inputImage = evened
        curve.point0 = CGPoint(x: 0, y: 0)
        curve.point1 = CGPoint(x: 0.3, y: 0.2)
        curve.point2 = CGPoint(x: 0.6, y: 0.55)
        curve.point3 = CGPoint(x: 0.85, y: 0.96)
        curve.point4 = CGPoint(x: 1, y: 1)

        let colour = CIFilter.colorControls()
        colour.inputImage = curve.outputImage
        colour.saturation = 1.15
        colour.contrast = 1.05
        return clamped(colour.outputImage ?? evened).cropped(to: image.extent)
    }

    /// The paper's brightness without the ink: shrink, spread the brightest pixels over the
    /// strokes, blur, and grow back.
    static func background(of image: CIImage) -> CIImage {
        let extent = image.extent
        let longest = max(extent.width, extent.height)
        guard longest > 0 else { return image }
        let scale = min(1, Constants.backgroundSize / longest)
        let small = image
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let maximum = CIFilter.morphologyMaximum()
        maximum.inputImage = small.clampedToExtent()
        maximum.radius = Constants.inkRadius

        let blurred = (maximum.outputImage ?? small)
            .applyingGaussianBlur(sigma: Constants.lightingBlur)
            .cropped(to: small.extent)
            .clampedToExtent()

        return blurred
            .transformed(by: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
            .cropped(to: extent)
    }

    static func monochrome(_ image: CIImage) -> CIImage {
        let grey = CIFilter.colorControls()
        grey.inputImage = image
        grey.saturation = 0
        grey.contrast = 1.1
        return clamped(grey.outputImage ?? image).cropped(to: image.extent)
    }

    /// Ink or paper per pixel. Evening out the light first makes one threshold work across the
    /// page, like an adaptive threshold.
    static func blackAndWhite(_ image: CIImage) -> CIImage {
        let grey = monochrome(enhanced(image))
        let threshold = CIFilter.colorThreshold()
        threshold.inputImage = grey
        threshold.threshold = blackAndWhiteThreshold
        return (threshold.outputImage ?? grey).cropped(to: image.extent)
    }

    private static func clamped(_ image: CIImage) -> CIImage {
        let clamp = CIFilter.colorClamp()
        clamp.inputImage = image
        clamp.minComponents = CIVector(x: 0, y: 0, z: 0, w: 0)
        clamp.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)
        return clamp.outputImage ?? image
    }
}

private enum Constants {
    /// Longest side of the lighting estimate; lighting changes slowly across a page.
    static let backgroundSize: Double = 256
    /// Wider than a pen stroke at `backgroundSize`.
    static let inkRadius: Float = 4
    static let lightingBlur: Double = 6
}
