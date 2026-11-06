import Foundation

/// The outcome of an export. A success shows as a banner, a failure as an alert.
struct ExportAlert: Equatable, Sendable {
    let message: String
    let isSuccess: Bool
    /// The saved PDF, or the folder the pages went into, for Show in Finder and Open.
    var output: URL?
    /// The new files to offer in the share sheet when `output` is a folder of page images.
    var sharedFiles: [URL]

    init(message: String, isSuccess: Bool, output: URL? = nil, sharedFiles: [URL] = []) {
        self.message = message
        self.isSuccess = isSuccess
        self.output = output
        self.sharedFiles = sharedFiles
    }

    /// Returned when the export was cancelled before anything was written; never shown.
    static let cancelled = ExportAlert(message: "", isSuccess: false)
}
