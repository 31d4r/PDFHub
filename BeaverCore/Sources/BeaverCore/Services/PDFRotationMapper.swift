import Foundation

public enum PDFRotationMapper {
    /// Maps each URL to the user's rotation for it. Duplicate URLs are allowed;
    /// the first matching PDF wins.
    public static func mapRotationAngles(
        urls: [URL],
        from pdfs: [PDFItem]
    ) -> [URL: Int] {
        Dictionary(
            urls.map { url in
                (
                    url,
                    pdfs.first(where: { $0.url == url })?.rotationAngle.degrees ?? RotationAngle.zero.degrees
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// The file and page rotations for each URL, in the same order. URLs that aren't
    /// in the list get no rotation; the first matching PDF wins.
    public static func rotations(
        urls: [URL],
        from pdfs: [PDFItem]
    ) -> [PDFRotation] {
        urls.map { url in
            pdfs.first(where: { $0.url == url })?.rotation ?? .none
        }
    }
}
