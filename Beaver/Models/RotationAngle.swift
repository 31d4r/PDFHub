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

    func rotated(_ direction: RotationDirection) -> RotationAngle {
        switch direction {
        case .left: return rotatedLeft
        case .right: return rotatedRight
        }
    }
}
