import Foundation

/// The rules behind the banner after an export, kept apart from the view so they can be tested
/// on every platform.
enum ExportBannerPolicy {
    /// How long a banner stays on iPhone and iPad before it goes by itself.
    static let autoDismissDelay: Duration = .seconds(8)

    /// When the banner may go by itself, or `nil` to keep it until it's dismissed. It stays while
    /// VoiceOver runs, so it can be found and read, once someone has touched it, and while it
    /// offers a choice that would be lost, such as adding the new PDF to the list.
    static func autoDismissDelay(isVoiceOverRunning: Bool, hasInteracted: Bool, offersChoice: Bool) -> Duration? {
        guard !isVoiceOverRunning, !hasInteracted, !offersChoice else { return nil }
        return autoDismissDelay
    }

    /// A `shareddocuments://` link that opens the Files app at the folder with the output: the
    /// folder itself for split pages, the folder holding it for one PDF.
    static func filesAppURL(showing output: URL, isFolder: Bool) -> URL? {
        guard output.isFileURL else { return nil }
        let folder = isFolder ? output : output.deletingLastPathComponent()
        var components = URLComponents()
        components.scheme = "shareddocuments"
        components.path = folder.path(percentEncoded: false)
        return components.url
    }
}
