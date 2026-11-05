import CoreGraphics

/// Turns bitmaps by quarter turns with Core Graphics, so it works on macOS and iOS.
public enum ImageRotator {
    /// `image` turned clockwise by `angle`, or `image` itself for `.zero`.
    /// `nil` when a drawing context can't be made.
    public static func rotate(_ image: CGImage, by angle: RotationAngle) -> CGImage? {
        guard angle != .zero else { return image }
        let size = CGSize(width: image.width, height: image.height)
        let rotated = angle.rotatedSize(size)
        guard let context = CGContext(
            data: nil,
            width: Int(rotated.width),
            height: Int(rotated.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.interpolationQuality = .high
        context.concatenate(angle.drawingTransform(for: size))
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }
}
