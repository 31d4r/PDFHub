import CoreGraphics

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
}
