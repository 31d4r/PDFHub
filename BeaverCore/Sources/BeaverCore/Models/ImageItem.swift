import CoreGraphics
import Foundation

public struct ImageItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    /// A downsampled preview, upright by its EXIF orientation. The full-size image is only read when converting.
    public let thumbnail: CGImage
    /// The user's clockwise rotation, baked into the page when converting.
    public private(set) var rotationAngle: RotationAngle
    /// `thumbnail` turned by `rotationAngle`, for display.
    public private(set) var preview: CGImage

    public init(
        id: UUID = UUID(),
        url: URL,
        thumbnail: CGImage,
        rotationAngle: RotationAngle = .zero
    ) {
        self.id = id
        self.url = url
        self.thumbnail = thumbnail
        self.rotationAngle = rotationAngle
        self.preview = ImageRotator.rotate(thumbnail, by: rotationAngle) ?? thumbnail
    }

    /// Sets the rotation and redraws the preview to match.
    public mutating func setRotation(_ angle: RotationAngle) {
        guard angle != rotationAngle else { return }
        rotationAngle = angle
        preview = ImageRotator.rotate(thumbnail, by: angle) ?? thumbnail
    }

    public mutating func rotate(_ direction: RotationDirection) {
        setRotation(rotationAngle.rotated(direction))
    }

    public static func == (
        lhs: ImageItem,
        rhs: ImageItem
    ) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url && lhs.rotationAngle == rhs.rotationAngle
    }
}
