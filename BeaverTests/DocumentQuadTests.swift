import BeaverCore
import CoreGraphics
import Testing

struct DocumentQuadTests {
    private let expected = DocumentQuad(
        topLeft: CGPoint(x: 0.1, y: 0.9),
        topRight: CGPoint(x: 0.8, y: 0.95),
        bottomRight: CGPoint(x: 0.9, y: 0.1),
        bottomLeft: CGPoint(x: 0.15, y: 0.05)
    )

    @Test(arguments: [
        [0, 1, 2, 3], [3, 2, 1, 0], [2, 0, 3, 1], [1, 3, 0, 2], [0, 2, 1, 3]
    ])
    func ordersCornersClockwiseFromTopLeft(order: [Int]) throws {
        let points = order.map { expected.corners[$0] }
        let quad = try #require(DocumentQuad(unordered: points))
        #expect(quad == expected)
    }

    @Test func ordersAPageTiltedLikeADiamond() throws {
        let top = CGPoint(x: 0.5, y: 0.95)
        let right = CGPoint(x: 0.9, y: 0.5)
        let bottom = CGPoint(x: 0.5, y: 0.05)
        let left = CGPoint(x: 0.1, y: 0.52)
        let quad = try #require(DocumentQuad(unordered: [bottom, top, left, right]))
        #expect(quad.corners == [left, top, right, bottom] || quad.corners == [top, right, bottom, left])
        #expect(quad.isConvex)
    }

    @Test func needsFourDistinctPoints() {
        #expect(DocumentQuad(unordered: Array(expected.corners.prefix(3))) == nil)
        #expect(DocumentQuad(unordered: [expected.topLeft, expected.topLeft, expected.topRight, expected.bottomRight]) == nil)
    }

    @Test func orderingKeepsAnAlreadyOrderedQuad() throws {
        let quad = try #require(DocumentQuad(unordered: DocumentQuad.fullImage.corners))
        #expect(quad == .fullImage)
    }

    @Test func movingACornerStaysInsideTheImage() {
        let moved = DocumentQuad.fullImage.moving(.topRight, to: CGPoint(x: 1.4, y: -0.2))
        #expect(moved.topRight == CGPoint(x: 1, y: 0))
        #expect(moved.topLeft == DocumentQuad.fullImage.topLeft)
    }

    @Test func aFoldedQuadIsNotConvex() {
        let folded = DocumentQuad.fullImage.moving(.topLeft, to: CGPoint(x: 0.9, y: 0.1))
        #expect(!folded.isConvex)
        #expect(DocumentQuad.fullImage.isConvex)
    }

    @Test func outputSizeUsesTheLongerOppositeEdges() {
        let trapezoid = DocumentQuad(
            topLeft: CGPoint(x: 0.25, y: 1),
            topRight: CGPoint(x: 0.75, y: 1),
            bottomRight: CGPoint(x: 1, y: 0),
            bottomLeft: CGPoint(x: 0, y: 0)
        )
        let size = trapezoid.outputSize(in: CGSize(width: 400, height: 300))
        #expect(size.width == 400)
        #expect(size.height == (300.0 * 300 + 100 * 100).squareRoot().rounded())
    }

    @Test func areaIsTheShareOfTheImage() {
        #expect(DocumentQuad.fullImage.area == 1)
        let half = DocumentQuad.fullImage.moving(.topRight, to: CGPoint(x: 0.5, y: 1)).moving(.bottomRight, to: CGPoint(x: 0.5, y: 0))
        #expect(abs(half.area - 0.5) < 0.0001)
    }
}
