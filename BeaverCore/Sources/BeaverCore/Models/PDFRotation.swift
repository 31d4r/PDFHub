import Foundation

/// The user's rotations for one PDF: a turn for the whole file plus extra turns for
/// single pages (zero-based page index). Both are clockwise and come on top of the
/// rotation already saved in each page.
public struct PDFRotation: Equatable, Sendable {
    public var file: RotationAngle
    /// Only pages that are turned; never holds `.zero`.
    public private(set) var pages: [Int: RotationAngle]

    public static let none = PDFRotation()

    public init(file: RotationAngle = .zero, pages: [Int: RotationAngle] = [:]) {
        self.file = file
        self.pages = pages.filter { $0.key >= 0 && $0.value != .zero }
    }

    public func page(_ index: Int) -> RotationAngle {
        pages[index] ?? .zero
    }

    /// What the user sees for a page: the file turn plus the page's own turn.
    public func userRotation(forPage index: Int) -> RotationAngle {
        file.adding(page(index))
    }

    /// The /Rotate to write for a page: saved + file + page, in 0..<360.
    public func degrees(forPage index: Int, savedRotation: Int) -> Int {
        RotationAngle.normalized(savedRotation + file.degrees + page(index).degrees)
    }

    public mutating func setPage(_ index: Int, to angle: RotationAngle) {
        guard index >= 0 else { return }
        pages[index] = angle == .zero ? nil : angle
    }

    public mutating func rotatePages(_ indexes: some Sequence<Int>, _ direction: RotationDirection) {
        for index in Set(indexes) {
            setPage(index, to: page(index).rotated(direction))
        }
    }
}
