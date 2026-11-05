import Foundation

struct PDFItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var url: URL
    var rotationAngle: RotationAngle

    init(
        id: UUID = UUID(),
        url: URL,
        rotationAngle: RotationAngle = .zero
    ) {
        self.id = id
        self.url = url
        self.rotationAngle = rotationAngle
    }
}
