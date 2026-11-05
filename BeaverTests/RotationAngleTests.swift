import XCTest
@testable import Beaver

final class RotationAngleTests: XCTestCase {
    func testRotatedRightCycles() {
        XCTAssertEqual(RotationAngle.zero.rotatedRight, .ninety)
        XCTAssertEqual(RotationAngle.ninety.rotatedRight, .oneEighty)
        XCTAssertEqual(RotationAngle.oneEighty.rotatedRight, .twoSeventy)
        XCTAssertEqual(RotationAngle.twoSeventy.rotatedRight, .zero)
    }

    func testRotatedLeftCycles() {
        XCTAssertEqual(RotationAngle.zero.rotatedLeft, .twoSeventy)
        XCTAssertEqual(RotationAngle.twoSeventy.rotatedLeft, .oneEighty)
        XCTAssertEqual(RotationAngle.oneEighty.rotatedLeft, .ninety)
        XCTAssertEqual(RotationAngle.ninety.rotatedLeft, .zero)
    }

    func testRotatedDirection() {
        XCTAssertEqual(RotationAngle.zero.rotated(.right), .ninety)
        XCTAssertEqual(RotationAngle.zero.rotated(.left), .twoSeventy)
    }

    func testDegreesMatchRawValues() {
        XCTAssertEqual(RotationAngle.zero.degrees, 0)
        XCTAssertEqual(RotationAngle.ninety.degrees, 90)
        XCTAssertEqual(RotationAngle.oneEighty.degrees, 180)
        XCTAssertEqual(RotationAngle.twoSeventy.degrees, 270)
    }
}
