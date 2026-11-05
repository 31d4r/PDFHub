import BeaverCore
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Beaver

struct DroppedFileKindTests {
    @Test func pdfAcceptsOnlyPDFFiles() {
        let urls = ["a.pdf", "b.PDF", "c.png", "d.txt"].map { URL(fileURLWithPath: "/tmp/\($0)") }
        #expect(DroppedFileKind.pdf.filter(urls).map(\.lastPathComponent) == ["a.pdf", "b.PDF"])
    }

    @Test func imageAcceptsSupportedImageTypes() {
        let urls = ["a.png", "b.JPG", "c.heic", "d.pdf", "e.txt", "f.tif"].map { URL(fileURLWithPath: "/tmp/\($0)") }
        #expect(DroppedFileKind.image.filter(urls).map(\.lastPathComponent) == ["a.png", "b.JPG", "c.heic", "f.tif"])
    }

    @Test func rejectsNonFileURLs() {
        let url = URL(string: "https://example.com/file.pdf")!
        #expect(!DroppedFileKind.pdf.accepts(url))
    }

    @Test func usesContentTypeConformance() {
        #expect(DroppedFileKind.pdf.accepts(UTType.pdf))
        #expect(!DroppedFileKind.pdf.accepts(UTType.png))
        #expect(DroppedFileKind.image.accepts(UTType.jpeg))
        #expect(!DroppedFileKind.image.accepts(UTType.plainText))
    }
}
