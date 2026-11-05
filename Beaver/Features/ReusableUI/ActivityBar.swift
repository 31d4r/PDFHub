import SwiftUI

/// Inline progress under the grid while an export runs, instead of a modal overlay.
/// Cancel (⌘.) stops it before anything is written.
struct ActivityBar: View {
    let title: String
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.updatesFrequently)
            Spacer()
            Button(DesignSystem.Export.cancel, action: onCancel)
                .keyboardShortcut(".", modifiers: .command)
                .help(DesignSystem.Export.cancelHelp)
        }
        .padding(.horizontal, DesignSystem.Spacing.medium)
        .padding(.vertical, DesignSystem.Spacing.small)
        .background {
            if reduceTransparency {
                Rectangle().fill(.background)
            } else {
                Rectangle().fill(.bar)
            }
        }
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .contain)
    }
}
