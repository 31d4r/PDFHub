import BeaverCore
import SwiftUI

/// Accepts PDFs and images dropped from Finder or another app. Reports hovering through
/// `isTargeted` so the view under the pointer can highlight itself.
struct FileDropModifier: ViewModifier {
    @Binding var isTargeted: Bool
    let onDrop: ([URL]) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .dropDestination(for: URL.self) { urls, _ in
                let accepted = urls.filter { DroppedFileKind.pdf.accepts($0) || DroppedFileKind.image.accepts($0) }
                guard !accepted.isEmpty else { return false }
                onDrop(accepted)
                return true
            } isTargeted: { targeted in
                withAnimation(reduceMotion ? nil : .easeOut(duration: Constants.highlightDuration)) {
                    isTargeted = targeted
                }
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
