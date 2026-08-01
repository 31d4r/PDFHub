import Foundation

struct PDF: Identifiable, Equatable {
    let id: UUID
    var pdfURL: URL
    var rotationAngle: RotationAngle

    init(
        id: UUID = UUID(),
        pdfURL: URL,
        rotationAngle: RotationAngle = .zero
    ) {
        self.id = id
        self.pdfURL = pdfURL
        self.rotationAngle = rotationAngle
    }
}
