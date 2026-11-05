import BeaverCore
import CoreGraphics
import Testing

struct DocumentDetectorTests {
    /// A white sheet, slightly turned, on a dark desk.
    @Test func findsAPageOnADarkDesk() async throws {
        let truth = DocumentQuad(
            topLeft: CGPoint(x: 0.22, y: 0.85),
            topRight: CGPoint(x: 0.78, y: 0.88),
            bottomRight: CGPoint(x: 0.8, y: 0.12),
            bottomLeft: CGPoint(x: 0.2, y: 0.15)
        )
        let width = 900, height = 1200
        let image = ScanImages.make(width: width, height: height, background: ScanImages.grey(0.15)) { context in
            let points = truth.points(in: CGSize(width: width, height: height))
            context.setFillColor(ScanImages.grey(0.95))
            context.addLines(between: points)
            context.closePath()
            context.fillPath()
        }
        let found = try #require(await DocumentDetector.detect(in: image))
        for (detected, expected) in zip(found.corners, truth.corners) {
            #expect(abs(detected.x - expected.x) < 0.04)
            #expect(abs(detected.y - expected.y) < 0.04)
        }
    }

    @Test func aBlankPhotoHasNoPage() async {
        let image = ScanImages.make(width: 600, height: 800, background: ScanImages.grey(0.5))
        #expect(await DocumentDetector.detect(in: image) == nil)
    }
}
