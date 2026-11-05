import BeaverCore
import CoreGraphics
import Testing

/// Black & White on a crumpled page in a strong shadow: light falls from the top left to 15%
/// in the bottom right, folds and creases a little darker than the paper cross it, the camera
/// adds noise, and lines of text run down the page. Only the text should come out black.
struct CrumpledPageTests {
    static let width = 600
    static let height = 800
    static let paper = 0.92
    static let ink = 0.08

    /// Text lines from the top: 6 px tall, in dashes like words.
    static let lineTops = Array(stride(from: 80, to: 760, by: 60))
    static let lineHeight = 6
    static let margin = 60

    static func isText(column: Int, row: Int) -> Bool {
        guard column >= margin, column < width - margin else { return false }
        guard lineTops.contains(where: { row >= $0 && row < $0 + lineHeight }) else { return false }
        return (column - margin) % 40 < 30
    }

    static func page() -> CGImage {
        ScanImages.make(width: width, height: height) { column, row in
            let x = Double(column) / Double(width - 1)
            let y = Double(row) / Double(height - 1)
            // A strong shadow: full light in one corner, 15% of it in the opposite one.
            let light = 1 - 0.85 * min(1, (x + y) / 2 * 1.1)
            // Wrinkles: each fold darkens gradually towards a crisp ridge, up to 14%, and thin
            // creases cross them a little darker still.
            let fold = Double((column + row / 2) % 80) / 80
            var wrinkle = 1 - 0.3 * fold * fold
            if (column * 2 + row) % 130 < 3 { wrinkle *= 0.9 }
            // Camera noise of a few percent, the same every run.
            let noise = 1 + 0.04 * (noiseValue(column, row) - 0.5)
            let base = isText(column: column, row: row) ? ink : paper
            let value = base * light * wrinkle * noise
            return (value, value, value)
        }
    }

    /// A repeatable value from 0 to 1 for each pixel.
    private static func noiseValue(_ column: Int, _ row: Int) -> Double {
        var hash = UInt64(column &* 73_856_093 ^ row &* 19_349_663)
        hash = (hash ^ (hash >> 13)) &* 0x5bd1_e995
        hash ^= hash >> 15
        return Double(hash % 1000) / 999
    }

    /// Shares of white paper away from the text and of black text, sampled on `image`, which may
    /// be smaller than the page.
    static func measure(_ image: CGImage) -> (paperWhite: Double, textBlack: Double) {
        let bytes = ScanImages.bytes(of: image)
        let scaleX = Double(width) / Double(image.width)
        let scaleY = Double(height) / Double(image.height)
        var paperCount = 0, whiteCount = 0, textCount = 0, blackCount = 0
        for row in 0..<image.height {
            for column in 0..<image.width {
                let pageColumn = Int((Double(column) + 0.5) * scaleX)
                let pageRow = Int((Double(row) + 0.5) * scaleY)
                let value = bytes[(row * image.width + column) * 4]
                // Text is measured in the middle of its strokes, paper well clear of them.
                let nearText = lineTops.contains { pageRow >= $0 - 8 && pageRow < $0 + lineHeight + 8 }
                if !nearText {
                    paperCount += 1
                    if value == 255 { whiteCount += 1 }
                } else if isText(column: pageColumn, row: pageRow),
                          isText(column: pageColumn - 3, row: pageRow), isText(column: pageColumn + 3, row: pageRow),
                          isText(column: pageColumn, row: pageRow - 2), isText(column: pageColumn, row: pageRow + 2) {
                    textCount += 1
                    if value == 0 { blackCount += 1 }
                }
            }
        }
        return (Double(whiteCount) / Double(max(paperCount, 1)), Double(blackCount) / Double(max(textCount, 1)))
    }

    @Test func shadowsAndWrinklesTurnWhiteAndTextStaysBlack() throws {
        let page = try #require(ScanImageProcessor().process(Self.page(), filter: .blackAndWhite))
        let result = Self.measure(page)
        #expect(result.paperWhite > 0.9, "paper white: \(result.paperWhite)")
        #expect(result.textBlack > 0.97, "text black: \(result.textBlack)")
    }

    /// The filter strip and the review show previews; they must look like the saved page.
    @Test func thePreviewLooksLikeTheSavedPage() throws {
        let preview = try #require(
            ScanImageProcessor().preview(Self.page(), quad: .fullImage, filter: .blackAndWhite, maxPixelSize: 400)
        )
        #expect(preview.height == 400)
        let result = Self.measure(preview)
        #expect(result.paperWhite > 0.9, "paper white: \(result.paperWhite)")
        #expect(result.textBlack > 0.9, "text black: \(result.textBlack)")
    }
}
