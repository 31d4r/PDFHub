import Foundation

enum RotationAngle: Int, CaseIterable, Equatable {
    case zero = 0
    case ninety = 90
    case oneEighty = 180
    case twoSeventy = 270

    var degrees: Int { rawValue }

    var rotatedLeft: RotationAngle {
        switch self {
        case .zero: return .twoSeventy
        case .ninety: return .zero
        case .oneEighty: return .ninety
        case .twoSeventy: return .oneEighty
        }
    }

    var rotatedRight: RotationAngle {
        switch self {
        case .zero: return .ninety
        case .ninety: return .oneEighty
        case .oneEighty: return .twoSeventy
        case .twoSeventy: return .zero
        }
    }

    /// Adds this user rotation to a page's existing rotation, keeping the result in 0..<360.
    func applied(to pageRotation: Int) -> Int {
        Self.normalized(pageRotation + degrees)
    }

    static func normalized(_ degrees: Int) -> Int {
        ((degrees % 360) + 360) % 360
    }

    func rotated(_ direction: RotationDirection) -> RotationAngle {
        switch direction {
        case .left: return rotatedLeft
        case .right: return rotatedRight
        }
    }
}
