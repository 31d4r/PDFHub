import Foundation

public struct PDFItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var url: URL
    public var rotationAngle: RotationAngle

    public init(
        id: UUID = UUID(),
        url: URL,
        rotationAngle: RotationAngle = .zero
    ) {
        self.id = id
        self.url = url
        self.rotationAngle = rotationAngle
    }
}
