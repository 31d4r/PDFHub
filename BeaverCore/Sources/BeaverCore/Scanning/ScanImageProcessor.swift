import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Flattens and cleans up photos of paper pages with Core Image, the same way on iOS and macOS.
/// The same input always gives the same pixels, so previews match the saved PDF.
public struct ScanImageProcessor: Sendable {
    /// Longest side kept from a camera photo: sharp text at A4 without huge files.
    public static let maximumPixelSize = 3200
    /// In Black & White, a pixel darker than this share of its neighbourhood's brightness is ink.
    /// Anything lighter, such as the shaded side of a fold, is paper.
    static let blackAndWhiteThreshold: Float = 0.85

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
        let evened = divided(image, by: background(of: image, lighting: .smooth))

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

    /// How closely a lighting estimate follows the page.
    struct Lighting {
        /// Longest side the page is shrunk to; the radius and blur are in its pixels.
        let size: Double
        /// Wider than the strokes it spreads the paper over.
        let inkRadius: Double
        let blur: Double
        /// The estimate never goes below this.
        let darkest: CGFloat

        /// Enhanced: lighting changes slowly across a page, and dark content stays dark because
        /// the estimate never drops below `darkestPaper`.
        static let smooth = Lighting(size: 256, inkRadius: 6, blur: 8, darkest: Constants.darkestPaper)
        /// Black & White: close enough to follow deep shadows and the shaded sides of folds, so
        /// they can be told apart from ink. Wider than text strokes; thicker filled shapes are
        /// kept black by the dark test instead.
        static let close = Lighting(size: 512, inkRadius: 6, blur: 4, darkest: 0.04)
    }

    /// The paper's brightness without the ink, as grey: the brightest channel of each pixel,
    /// shrunk, spread over the strokes, blurred, grown back, and kept above `lighting.darkest`.
    /// An image smaller than `lighting.size`, such as a preview, gets a radius and blur scaled
    /// down with it, so it is estimated like the full page.
    static func background(of image: CIImage, lighting: Lighting) -> CIImage {
        let extent = image.extent
        let longest = max(extent.width, extent.height)
        guard longest > 0 else { return image }
        let scale = min(1, lighting.size / longest)
        let reach = longest * scale / lighting.size
        let brightest = CIFilter.maximumComponent()
        brightest.inputImage = image
        let small = (brightest.outputImage ?? image)
            .transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let maximum = CIFilter.morphologyMaximum()
        maximum.inputImage = small.clampedToExtent()
        maximum.radius = Float(lighting.inkRadius * reach)

        let blurred = (maximum.outputImage ?? small)
            .applyingGaussianBlur(sigma: lighting.blur * reach)
            .cropped(to: small.extent)

        let floor = CIFilter.colorClamp()
        floor.inputImage = blurred
        let darkest = lighting.darkest
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

    /// Ink or paper per pixel, like a photocopier that ignores the creases:
    ///
    /// 1. The grey page is divided by a close estimate of its lighting, which follows deep
    ///    shadows and the shaded sides of folds, so the paper comes out evenly white.
    /// 2. A pixel is ink when it is clearly darker than the evened page around it, by more than
    ///    `blackAndWhiteThreshold`, so faint pencil and light coloured text survive while smooth
    ///    shading, folds and camera noise go white. The neighbourhood grows with the page, so a
    ///    preview thresholds the same way as the full page.
    /// 3. A pixel is also ink when it is dark outright after Enhanced, so filled areas such as a
    ///    dark band stay solid. Enhanced lifts shadows, so only truly dark areas pass this.
    static func blackAndWhite(_ image: CIImage) -> CIImage {
        let extent = image.extent
        let longest = max(extent.width, extent.height)
        guard longest > 0 else { return image }
        let grey = monochrome(image)
        let evened = clamped(divided(grey, by: background(of: grey, lighting: .close))).cropped(to: extent)

        let floor = CIFilter.colorClamp()
        floor.inputImage = evened
            .clampedToExtent()
            .applyingGaussianBlur(sigma: longest * Constants.neighbourhood)
            .cropped(to: extent)
        floor.minComponents = CIVector(x: 0.02, y: 0.02, z: 0.02, w: 1)
        floor.maxComponents = CIVector(x: 1, y: 1, z: 1, w: 1)

        let local = CIFilter.colorThreshold()
        local.inputImage = clamped(divided(evened, by: floor.outputImage ?? evened)).cropped(to: extent)
        local.threshold = blackAndWhiteThreshold

        let dark = CIFilter.colorThreshold()
        dark.inputImage = monochrome(enhanced(image))
        dark.threshold = Constants.alwaysInk

        let both = CIFilter.minimumCompositing()
        both.inputImage = local.outputImage
        both.backgroundImage = dark.outputImage
        return (both.outputImage ?? grey).cropped(to: extent)
    }

    /// `image` over `divisor`, pixel by pixel.
    private static func divided(_ image: CIImage, by divisor: CIImage) -> CIImage {
        let divide = CIFilter.divideBlendMode()
        // Divide blend gives background ÷ input.
        divide.inputImage = divisor
        divide.backgroundImage = image
        return (divide.outputImage ?? image).cropped(to: image.extent)
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
    /// Enhanced's lighting estimate never goes below this, so dark content isn't mistaken for shadow.
    static let darkestPaper: CGFloat = 0.45
    /// Evened-out paper at or above this becomes white; fainter marks below it are kept.
    static let paperWhite: CGFloat = 0.94
    static let sharpness: Float = 0.3
    static let sharpenRadius: Float = 1.2
    /// Black & White's neighbourhood blur, as a share of the longest side, so a preview
    /// thresholds the same way as the full page.
    static let neighbourhood: Double = 0.05
    /// In Black & White, anything darker than this after Enhanced is ink whatever surrounds it.
    static let alwaysInk: Float = 0.3
}
