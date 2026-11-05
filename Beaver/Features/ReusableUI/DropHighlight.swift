import SwiftUI

/// Outlines the content while files are dragged over a non-empty list.
struct DropHighlight: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DesignSystem.Layout.selectionRadius, style: .continuous)
            .strokeBorder(Color.accentColor, lineWidth: 3)
            .background(Color.accentColor.opacity(0.06))
            .padding(4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
