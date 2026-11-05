import SwiftUI

/// Accepts files of one kind dropped from Finder and highlights the target while hovering.
struct FileDropModifier: ViewModifier {
    let kind: DroppedFileKind
    let onDrop: ([URL]) -> Void

    @State private var isTargeted = false

    func body(content: Content) -> some View {
        content
            .dropDestination(for: URL.self) { urls, _ in
                let accepted = kind.filter(urls)
                guard !accepted.isEmpty else { return false }
                onDrop(accepted)
                return true
            } isTargeted: { targeted in
                withAnimation(.easeInOut(duration: Constants.highlightAnimationDuration)) {
                    isTargeted = targeted
                }
            }
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous)
                        .strokeBorder(
                            DesignSystem.Colors.primaryGradientStart,
                            style: StrokeStyle(lineWidth: Constants.highlightLineWidth, dash: Constants.highlightDash)
                        )
                        .padding(Constants.highlightInset)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

extension View {
    func fileDrop(_ kind: DroppedFileKind, onDrop: @escaping ([URL]) -> Void) -> some View {
        modifier(FileDropModifier(kind: kind, onDrop: onDrop))
    }
}

private enum Constants {
    static let highlightLineWidth: CGFloat = 3
    static let highlightDash: [CGFloat] = [10, 6]
    static let highlightInset: CGFloat = 8
    static let highlightAnimationDuration: Double = 0.15
}
