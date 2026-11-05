import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Flattens and cleans up photos of paper pages with Core Image, the same way on iOS and macOS.
/// The same input always gives the same pixels, so previews match the saved PDF.
public struct ScanImageProcessor: Sendable {
    /// Longest side kept from a camera photo: sharp text at A4 without huge files.
    public static let maximumPixelSize = 3200
    /// In Black & White, a pixel darker than this share of its neighbourhood's brightness is ink.
    static let blackAndWhiteThreshold: Float = 0.9

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

    /// Evens out the lighting and whitens the paper while leaving colours and faint marks alone,
    /// like a phone's document scanner rather than a photocopier.
    ///
    /// The page is divided by a colourless estimate of the paper's brightness, so every channel of
    /// a pixel is scaled by the same amount: hue and saturation stay put, and a red heading can't
    /// be divided into white the way a per-channel estimate would. The estimate never drops below
    /// `Constants.darkestPaper`, so a dark band or a big logo is lifted a little at most instead of
    /// being taken for a shadow. Then a small gain pushes paper texture to white, a soft curve
    /// deepens the ink a touch, and a light sharpen crisps the edges.
    static func enhanced(_ image: CIImage) -> CIImage {
        let divide = CIFilter.divideBlendMode()
        // Divide blend gives background ÷ input: the page over its lighting.
        divide.inputImage = background(of: image)
        divide.backgroundImage = image
        let evened = (divide.outputImage ?? image).cropped(to: image.extent)

        let whitePoint = CIFilter.colorMatrix()
        whitePoint.inputImage = evened
        let gain = 1 / Constants.paperWhite
        whitePoint.rVector = CIVector(x: gain, y: 0, z: 0, w: 0)
        whitePoint.gVector = CIVector(x: 0, y: gain, z: 0, w: 0)
        whitePoint.bVector = CIVector(x: 0, y: 0, z: gain, w: 0)
        whitePoint.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        let whitened = clamped(whitePoint.outputImage ?? evened)

        let curve = CIFilter.toneCurve()
        curve.inputImage = whitened
        curve.point0 = CGPoint(x: 0, y: 0)
        curve.point1 = CGPoint(x: 0.25, y: 0.21)
        curve.point2 = CGPoint(x: 0.5, y: 0.47)
        curve.point3 = CGPoint(x: 0.75, y: 0.7)
        curve.point4 = CGPoint(x: 1, y: 1)

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = curve.outputImage ?? whitened
        sharpen.sharpness = Constants.sharpness
        sharpen.radius = Constants.sharpenRadius
        return clamped(sharpen.outputImage ?? whitened).cropped(to: image.extent)
    }

    /// The paper's brightness without the ink, as grey: the brightest channel of each pixel,
    /// shrunk, spread over the strokes, blurred, grown back, and kept above `darkestPaper`.
    static func background(of image: CIImage) -> CIImage {
        let extent = image.extent
        let longest = max(extent.width, extent.height)
        guard longest > 0 else { return image }
        let scale = min(1, Constants.backgroundSize / longest)
        let brightest = CIFilter.maximumComponent()
        brightest.inputImage = image
        let small = (brightest.outputImage ?? image)
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let maximum = CIFilter.morphologyMaximum()
        maximum.inputImage = small.clampedToExtent()
        maximum.radius = Constants.inkRadius

        let blurred = (maximum.outputImage ?? small)
            .applyingGaussianBlur(sigma: Constants.lightingBlur)
            .cropped(to: small.extent)

        let floor = CIFilter.colorClamp()
        floor.inputImage = blurred
        let darkest = Constants.darkestPaper
        floor.minComponents = CIVector(x: darkest, y: darkest, z: darkest, w: 1)
        floor.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)

        return (floor.outputImage ?? blurred)
            .clampedToExtent()
            .transformed(by: CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
            .transformed(by: CGAffineTransform(translationX: extent.minX, y: extent.minY))
            .cropped(to: extent)
    }

    /// Grey by luminance, with no extra contrast on top of `enhanced`.
    static func monochrome(_ image: CIImage) -> CIImage {
        let grey = CIFilter.colorControls()
        grey.inputImage = image
        grey.saturation = 0
        grey.contrast = 1
        return clamped(grey.outputImage ?? image).cropped(to: image.extent)
    }

    /// Ink or paper per pixel, by an adaptive threshold: a pixel is ink when it is clearly darker
    /// than its neighbourhood, so faint pencil and light coloured text survive next to bold
    /// print, or when it is dark outright, so filled areas such as a dark band stay solid.
    static func blackAndWhite(_ image: CIImage) -> CIImage {
        let grey = monochrome(enhanced(image))
        let extent = grey.extent
        let longest = max(extent.width, extent.height)
        guard longest > 0 else { return grey }

        let floor = CIFilter.colorClamp()
        floor.inputImage = grey
            .clampedToExtent()
            .applyingGaussianBlur(sigma: longest * Constants.neighbourhood)
            .cropped(to: extent)
        floor.minComponents = CIVector(x: 0.02, y: 0.02, z: 0.02, w: 1)
        floor.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)

        let relative = CIFilter.divideBlendMode()
        relative.inputImage = floor.outputImage
        relative.backgroundImage = grey

        let local = CIFilter.colorThreshold()
        local.inputImage = clamped(relative.outputImage ?? grey).cropped(to: extent)
        local.threshold = blackAndWhiteThreshold

        let dark = CIFilter.colorThreshold()
        dark.inputImage = grey
        dark.threshold = Constants.alwaysInk

        let both = CIFilter.minimumCompositing()
        both.inputImage = local.outputImage
        both.backgroundImage = dark.outputImage
        return (both.outputImage ?? grey).cropped(to: extent)
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
    static let inkRadius: Float = 6
    static let lightingBlur: Double = 8
    /// The lighting estimate never goes below this, so dark content isn't mistaken for shadow.
    static let darkestPaper: CGFloat = 0.45
    /// Evened-out paper at or above this becomes white; fainter marks below it are kept.
    static let paperWhite: CGFloat = 0.94
    static let sharpness: Float = 0.3
    static let sharpenRadius: Float = 1.2
    /// Black & White's neighbourhood blur, as a share of the longest side, so a preview
    /// thresholds the same way as the full page.
    static let neighbourhood: Double = 0.02
    /// In Black & White, anything darker than this is ink whatever surrounds it.
    static let alwaysInk: Float = 0.4
}
