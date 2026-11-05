import SwiftUI

/// Sets the importer's confirm button where the OS supports it (macOS 15, iOS 18).
struct FileDialogConfirmationLabel: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if #available(macOS 15.0, iOS 18.0, *) {
            content.fileDialogConfirmationLabel(label.map { Text($0) })
        } else {
            content
        }
    }
}
