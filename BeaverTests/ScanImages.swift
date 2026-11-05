import CoreGraphics
import Foundation

/// Bitmaps for scanner tests, drawn with Core Graphics so they work on macOS and iOS.
enum ScanImages {
    struct Pixel: Equatable {
        let red: Int
        let green: Int
        let blue: Int

        var brightness: Int { (red + green + blue) / 3 }
    }

    /// A canvas of `background` with `draw` run in y-up pixel coordinates.
    static func make(
        width: Int,
        height: Int,
        background: CGColor = CGColor(red: 1, green: 1, blue: 1, alpha: 1),
        draw: (CGContext) -> Void = { _ in }
    ) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(background)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        draw(context)
        return context.makeImage()!
    }

    static func grey(_ value: Double) -> CGColor {
        CGColor(red: value, green: value, blue: value, alpha: 1)
    }

    /// Every pixel as RGBA bytes, top row first.
    static func bytes(of image: CGImage) -> [UInt8] {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }

    /// The pixel at fractions of the width and height, measured from the top left.
    static func pixel(of image: CGImage, x: Double, y: Double) -> Pixel {
        let pixels = bytes(of: image)
        let column = min(image.width - 1, Int(Double(image.width) * x))
        let row = min(image.height - 1, Int(Double(image.height) * y))
        let offset = (row * image.width + column) * 4
        return Pixel(red: Int(pixels[offset]), green: Int(pixels[offset + 1]), blue: Int(pixels[offset + 2]))
    }

    /// A canvas whose every pixel comes from `colour(column, row)`, rows counted from the top,
    /// in sRGB components from 0 to 1.
    static func make(
        width: Int,
        height: Int,
        colour: (Int, Int) -> (red: Double, green: Double, blue: Double)
    ) -> CGImage {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        for row in 0..<height {
            for column in 0..<width {
                let value = colour(column, row)
                let offset = (row * width + column) * 4
                pixels[offset] = byte(value.red)
                pixels[offset + 1] = byte(value.green)
                pixels[offset + 2] = byte(value.blue)
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8((min(1, max(0, value)) * 255).rounded())
    }
}

extension ScanImages.Pixel {
    private var components: [Double] { [red, green, blue].map { Double($0) / 255 } }

    /// WCAG relative luminance, 0 for black to 1 for white.
    var luminance: Double {
        let linear = components.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }

    /// WCAG contrast ratio, from 1 (the same) to 21 (black on white).
    func contrast(with other: Self) -> Double {
        let (light, dark) = (max(luminance, other.luminance), min(luminance, other.luminance))
        return (light + 0.05) / (dark + 0.05)
    }

    /// Hue in degrees and HSV saturation from 0 to 1.
    var hueAndSaturation: (hue: Double, saturation: Double) {
        let (r, g, b) = (components[0], components[1], components[2])
        let top = max(r, g, b), spread = top - min(r, g, b)
        guard spread > 0 else { return (0, 0) }
        let sector: Double
        if top == r {
            sector = (g - b) / spread
        } else if top == g {
            sector = (b - r) / spread + 2
        } else {
            sector = (r - g) / spread + 4
        }
        let hue = (sector * 60).truncatingRemainder(dividingBy: 360)
        return (hue < 0 ? hue + 360 : hue, spread / top)
    }
}

/// The shorter way round the colour wheel between two hues, in degrees.
func hueDistance(_ a: Double, _ b: Double) -> Double {
    let difference = abs(a - b).truncatingRemainder(dividingBy: 360)
    return min(difference, 360 - difference)
}
