import Foundation

/// The outcome of an export. A success shows as a banner, a failure as an alert.
struct ExportAlert: Equatable, Sendable {
    let message: String
    let isSuccess: Bool
    /// The saved PDF, or the folder the pages went into, for Show in Finder and Open.
    var output: URL?

    init(message: String, isSuccess: Bool, output: URL? = nil) {
        self.message = message
        self.isSuccess = isSuccess
        self.output = output
    }

    /// Returned when the export was cancelled before anything was written; never shown.
    static let cancelled = ExportAlert(message: "", isSuccess: false)
}
