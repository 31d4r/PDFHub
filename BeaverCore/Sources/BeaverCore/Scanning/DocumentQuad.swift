import CoreGraphics

/// The four corners of a page in a photo, as fractions of the image size with the origin at the
/// bottom left (y up), the convention Vision and Core Image use.
public struct DocumentQuad: Hashable, Sendable {
    public enum Corner: Int, CaseIterable, Sendable {
        case topLeft, topRight, bottomRight, bottomLeft
    }

    public var topLeft: CGPoint
    public var topRight: CGPoint
    public var bottomRight: CGPoint
    public var bottomLeft: CGPoint

    public init(topLeft: CGPoint, topRight: CGPoint, bottomRight: CGPoint, bottomLeft: CGPoint) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomRight = bottomRight
        self.bottomLeft = bottomLeft
    }

    /// The whole image, for a page that needs no crop.
    public static let fullImage = DocumentQuad(
        topLeft: CGPoint(x: 0, y: 1),
        topRight: CGPoint(x: 1, y: 1),
        bottomRight: CGPoint(x: 1, y: 0),
        bottomLeft: CGPoint(x: 0, y: 0)
    )

    /// Four points in any order, put clockwise from the top left as seen in the photo.
    /// `nil` unless there are exactly four distinct points.
    public init?(unordered points: [CGPoint]) {
        guard points.count == 4, Set(points.map { [$0.x, $0.y] }).count == 4 else { return nil }
        let centre = CGPoint(
            x: points.map(\.x).reduce(0, +) / 4,
            y: points.map(\.y).reduce(0, +) / 4
        )
        // Clockwise with y up is decreasing angle around the centre.
        let clockwise = points.sorted {
            atan2($0.y - centre.y, $0.x - centre.x) > atan2($1.y - centre.y, $1.x - centre.x)
        }
        // The top left is furthest up and to the left: the smallest x - y.
        let start = clockwise.indices.min { clockwise[$0].x - clockwise[$0].y < clockwise[$1].x - clockwise[$1].y } ?? 0
        let ordered = (0..<4).map { clockwise[(start + $0) % 4] }
        self.init(topLeft: ordered[0], topRight: ordered[1], bottomRight: ordered[2], bottomLeft: ordered[3])
    }

    /// Clockwise from the top left.
    public var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    public subscript(corner: Corner) -> CGPoint {
        get { corners[corner.rawValue] }
        set {
            switch corner {
            case .topLeft: topLeft = newValue
            case .topRight: topRight = newValue
            case .bottomRight: bottomRight = newValue
            case .bottomLeft: bottomLeft = newValue
            }
        }
    }

    /// `corner` moved to `point`, kept inside the image.
    public func moving(_ corner: Corner, to point: CGPoint) -> DocumentQuad {
        var quad = self
        quad[corner] = CGPoint(x: min(max(point.x, 0), 1), y: min(max(point.y, 0), 1))
        return quad
    }

    /// The corners in pixels of an image of `size`, still y up.
    public func points(in size: CGSize) -> [CGPoint] {
        corners.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }

    /// The size of the flattened page from an image of `size`: its longer top or bottom edge
    /// by its longer left or right edge, so no detail is thrown away.
    public func outputSize(in size: CGSize) -> CGSize {
        let p = points(in: size)
        let width = max(Self.distance(p[0], p[1]), Self.distance(p[3], p[2]))
        let height = max(Self.distance(p[0], p[3]), Self.distance(p[1], p[2]))
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    /// Whether the corners make a page shape: every turn the same way and no edge crossing,
    /// as a dragged corner could otherwise fold the page over itself.
    public var isConvex: Bool {
        let p = corners
        var sign = 0.0
        for index in 0..<4 {
            let a = p[index], b = p[(index + 1) % 4], c = p[(index + 2) % 4]
            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            guard abs(cross) > .ulpOfOne else { return false }
            if sign == 0 {
                sign = cross
            } else if (cross > 0) != (sign > 0) {
                return false
            }
        }
        return true
    }

    /// The share of the image the page covers, from 0 to 1.
    public var area: Double {
        let p = corners
        var sum = 0.0
        for index in 0..<4 {
            let a = p[index], b = p[(index + 1) % 4]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
        hypot(b.x - a.x, b.y - a.y)
    }
}
