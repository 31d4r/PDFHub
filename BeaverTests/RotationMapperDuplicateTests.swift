import Foundation
import Testing
@testable import Beaver

@Suite("Rotation mapper")
struct RotationMapperDuplicateTests {
    @Test("Duplicate URLs do not crash and keep the first rotation")
    func duplicateURLs() {
        let url = URL(fileURLWithPath: "/tmp/dup.pdf")
        let pdfs = [
            PDF(pdfURL: url, rotationAngle: .ninety),
            PDF(pdfURL: url, rotationAngle: .oneEighty),
        ]

        let mapped = PDFRotationMapper.mapRotationAngles(urls: [url, url], from: pdfs)

        #expect(mapped.count == 1)
        #expect(mapped[url] == 90)
    }
}
