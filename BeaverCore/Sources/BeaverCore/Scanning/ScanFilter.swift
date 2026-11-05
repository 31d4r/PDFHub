/// How a scanned page is cleaned up, as in a document scanner app.
public enum ScanFilter: String, CaseIterable, Sendable {
    /// The photo as taken, only cropped and flattened.
    case original
    /// Shadows and uneven light removed, paper whitened and colour kept.
    case enhanced
    /// As enhanced, in shades of grey.
    case grayscale
    /// Pure black ink on white paper, best for text.
    case blackAndWhite

    /// What a new scan starts with.
    public static let `default`: ScanFilter = .enhanced
}
