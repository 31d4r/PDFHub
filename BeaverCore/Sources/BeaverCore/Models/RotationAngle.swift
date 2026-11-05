import Foundation

public enum RotationAngle: Int, CaseIterable, Equatable, Sendable {
    case zero = 0
    case ninety = 90
    case oneEighty = 180
    case twoSeventy = 270

    public var degrees: Int { rawValue }

    public var rotatedLeft: RotationAngle {
        switch self {
        case .zero: return .twoSeventy
        case .ninety: return .zero
        case .oneEighty: return .ninety
        case .twoSeventy: return .oneEighty
        }
    }

    public var rotatedRight: RotationAngle {
        switch self {
        case .zero: return .ninety
        case .ninety: return .oneEighty
        case .oneEighty: return .twoSeventy
        case .twoSeventy: return .zero
        }
    }

    /// Adds this user rotation to a page's existing rotation, keeping the result in 0..<360.
    public func applied(to pageRotation: Int) -> Int {
        Self.normalized(pageRotation + degrees)
    }

    public static func normalized(_ degrees: Int) -> Int {
        ((degrees % 360) + 360) % 360
    }

    public func rotated(_ direction: RotationDirection) -> RotationAngle {
        switch direction {
        case .left: return rotatedLeft
        case .right: return rotatedRight
        }
    }
}
