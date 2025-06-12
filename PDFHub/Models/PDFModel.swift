import Foundation

struct PDF: Identifiable {
    var id = UUID()
    var pdfURL: URL
    var rotationAngle: Int
}
