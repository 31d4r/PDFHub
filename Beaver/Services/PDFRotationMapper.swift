import Foundation

enum PDFRotationMapper {
    /// Maps each URL to the user's rotation for it. Duplicate URLs are allowed;
    /// the first matching PDF wins.
    static func mapRotationAngles(
        urls: [URL],
        from pdfs: [PDF]
    ) -> [URL: Int] {
        Dictionary(
            urls.map { url in
                (
                    url,
                    pdfs.first(where: { $0.pdfURL == url })?.rotationAngle.degrees ?? RotationAngle.zero.degrees
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
    }
}
