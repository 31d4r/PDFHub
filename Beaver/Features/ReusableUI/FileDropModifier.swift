import BeaverCore
import SwiftUI

/// Accepts PDFs and images dropped from Finder, Files or another app. Reports hovering through
/// `isTargeted` so the view under the pointer can highlight itself.
struct FileDropModifier: ViewModifier {
    @Binding var isTargeted: Bool
    let onDrop: ([URL]) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .dropDestination(for: URL.self) { urls, _ in
                accept(urls)
            } isTargeted: { targeted in
                setTargeted(targeted)
            }
        #else
        // Other iPad apps send copies of files rather than locations Beaver could read.
        content
            .dropDestination(for: ImportedFile.self) { files, _ in
                accept(files.map(\.url))
            } isTargeted: { targeted in
                setTargeted(targeted)
            }
        #endif
    }

    private func accept(_ urls: [URL]) -> Bool {
        let accepted = urls.filter { DroppedFileKind.pdf.accepts($0) || DroppedFileKind.image.accepts($0) }
        guard !accepted.isEmpty else { return false }
        onDrop(accepted)
        return true
    }

    private func setTargeted(_ targeted: Bool) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: Constants.highlightDuration)) {
            isTargeted = targeted
        }
    }
}

extension View {
    func fileDrop(isTargeted: Binding<Bool>, onDrop: @escaping ([URL]) -> Void) -> some View {
        modifier(FileDropModifier(isTargeted: isTargeted, onDrop: onDrop))
    }
}

private enum Constants {
    static let highlightDuration: Double = 0.15
}
