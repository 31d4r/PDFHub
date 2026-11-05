import BeaverCore
import SwiftUI

/// Words and sizes for iPhone and iPad. They are not behind `#if os(iOS)` so the Mac build
/// keeps them in the String Catalog too.
extension DesignSystem {
    enum Mobile {
        static let gridSpacing: CGFloat = 12
        static let contentPadding: CGFloat = 16
        /// The narrowest card, before Dynamic Type scales it.
        static let minimumCardWidth: CGFloat = 150
        static let selectionBadgeSize: CGFloat = 28

        static var add: String { String(localized: "mobile.add", defaultValue: "Add", comment: "iOS toolbar menu that adds photos or files") }
        static var browseFiles: String { String(localized: "mobile.browseFiles", defaultValue: "Browse Files", comment: "iOS: add PDFs or images from the Files app") }
        static var select: String { String(localized: "mobile.select", defaultValue: "Select", comment: "iOS: start choosing files in the grid") }
        static var done: String { String(localized: "mobile.done", defaultValue: "Done", comment: "iOS: stop choosing files in the grid") }
        static var actions: String { String(localized: "mobile.actions", defaultValue: "Actions", comment: "iOS toolbar menu with Merge, Split, Convert and Combine") }
        static var selectItems: String { String(localized: "mobile.selectItems", defaultValue: "Select Items", comment: "iOS title while choosing files, before any is chosen") }

        /// "3 Selected", the title while choosing files.
        static func selectedTitle(_ count: Int) -> String {
            String(localized: "mobile.selectedTitle", defaultValue: "\(count) Selected", comment: "iOS title while choosing files")
        }

        static var addHelp: String {
            String(localized: "mobile.add.help", defaultValue: "Add PDFs and images from Files", comment: "iOS: accessibility hint for Add")
        }
        static var selectHelp: String {
            String(localized: "mobile.select.help", defaultValue: "Choose files to rotate, remove or turn into a PDF", comment: "iOS: accessibility hint for Select")
        }
        static var actionsHelp: String {
            String(localized: "mobile.actions.help", defaultValue: "Merge, split or convert the selected files, or all of them", comment: "iOS: accessibility hint for the Actions menu")
        }

        static var emptyTitle: String { String(localized: "mobile.empty.title", defaultValue: "Add Your First Document", comment: "iOS empty state title") }
        static var emptyMessage: String {
            String(
                localized: "mobile.empty.message",
                defaultValue: "Add PDFs and photos, then merge them, split them into pages or turn them into one PDF. Your originals are never changed.",
                comment: "iOS empty state message"
            )
        }

        // The export banner on iOS.
        static var share: String { String(localized: "mobile.share", defaultValue: "Share", comment: "iOS: share the saved PDF") }
        static var shareHelp: String {
            String(localized: "mobile.share.help", defaultValue: "Send the PDF with AirDrop, Mail, Messages and more", comment: "iOS: accessibility hint for Share")
        }
        static var saveToFiles: String { String(localized: "mobile.saveToFiles", defaultValue: "Save to Files", comment: "iOS: save a copy of the PDF to a place in Files") }
        static var saveToFilesHelp: String {
            String(localized: "mobile.saveToFiles.help", defaultValue: "Save a copy in iCloud Drive or another place in Files", comment: "iOS: accessibility hint for Save to Files")
        }
        static var showInFiles: String { String(localized: "mobile.showInFiles", defaultValue: "Show in Files", comment: "iOS: open the Files app at the saved pages") }
        static var showInFilesHelp: String {
            String(localized: "mobile.showInFiles.help", defaultValue: "Open the folder with the saved pages in Files", comment: "iOS: accessibility hint for Show in Files")
        }
        static func savedCopy(_ fileName: String) -> String {
            String(localized: "mobile.savedCopy", defaultValue: "Saved a copy of \(fileName)", comment: "iOS: VoiceOver announcement after Save to Files")
        }
        static var selectedBadge: String { String(localized: "mobile.selected", defaultValue: "Selected", comment: "iOS: VoiceOver value of a chosen file") }
    }
}
