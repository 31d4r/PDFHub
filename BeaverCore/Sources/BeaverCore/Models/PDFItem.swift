import Foundation

public struct PDFItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var url: URL
    /// The user's turn for the whole file.
    public var rotationAngle: RotationAngle
    /// Extra turns for single pages, by zero-based page index. Never holds `.zero`.
    public private(set) var pageRotations: [Int: RotationAngle]

    public init(
        id: UUID = UUID(),
        url: URL,
        rotationAngle: RotationAngle = .zero,
        pageRotations: [Int: RotationAngle] = [:]
    ) {
        self.id = id
        self.url = url
        self.rotationAngle = rotationAngle
        self.pageRotations = PDFRotation(pages: pageRotations).pages
    }

    public var hasPageRotations: Bool { !pageRotations.isEmpty }

    /// Everything the user turned, for export and undo.
    public var rotation: PDFRotation {
        get { PDFRotation(file: rotationAngle, pages: pageRotations) }
        set {
            rotationAngle = newValue.file
            pageRotations = newValue.pages
        }
    }

    public mutating func rotatePages(_ indexes: some Sequence<Int>, _ direction: RotationDirection) {
        rotation.rotatePages(indexes, direction)
    }
}
