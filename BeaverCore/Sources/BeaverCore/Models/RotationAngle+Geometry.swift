import CoreGraphics

public extension RotationAngle {
    /// Builds an angle from any number of degrees, rounded down to a quarter turn.
    init(normalizing degrees: Int) {
        let normalized = Self.normalized(degrees)
        self = RotationAngle(rawValue: normalized - normalized % 90) ?? .zero
    }

    /// Whether the angle swaps width and height.
    var isQuarterTurn: Bool {
        self == .ninety || self == .twoSeventy
    }

    /// This angle followed by `other`.
    func adding(_ other: RotationAngle) -> RotationAngle {
        RotationAngle(normalizing: degrees + other.degrees)
    }

    /// The size of a `size` rectangle after turning it clockwise by this angle.
    func rotatedSize(_ size: CGSize) -> CGSize {
        isQuarterTurn ? CGSize(width: size.height, height: size.width) : size
    }

    /// Maps a rectangle at the origin with `size` onto a `rotatedSize(size)` rectangle,
    /// turned clockwise by this angle. Core Graphics coordinates (y up).
    func drawingTransform(for size: CGSize) -> CGAffineTransform {
        switch self {
        case .zero:
            return .identity
        case .ninety:
            return CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: size.width)
        case .oneEighty:
            return CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: size.width, ty: size.height)
        case .twoSeventy:
            return CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: size.height, ty: 0)
        }
    }
}
