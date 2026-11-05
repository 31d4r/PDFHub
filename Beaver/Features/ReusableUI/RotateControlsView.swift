import BeaverCore
import SwiftUI

/// Compact rotate-left and rotate-right buttons on a material capsule, for hover controls
/// on thumbnails. Reports the direction so the caller routes the change through the reactor.
struct RotateControlsView: View {
    /// The file or page name, so VoiceOver says what turns ("Rotate photo.png left").
    var subject: String?
    var isDisabled = false
    /// An extra button after the rotate pair, such as Show Pages.
    var extra: CardAction?
    let onRotate: (RotationDirection) -> Void

    var body: some View {
        HStack(spacing: 0) {
            button(
                DesignSystem.Workspace.rotateLeft,
                systemImage: DesignSystem.Icons.rotateLeft,
                label: subject.map(DesignSystem.Accessibility.rotateLeft)
            ) { onRotate(.left) }
            button(
                DesignSystem.Workspace.rotateRight,
                systemImage: DesignSystem.Icons.rotateRight,
                label: subject.map(DesignSystem.Accessibility.rotateRight)
            ) { onRotate(.right) }
            if let extra {
                Divider()
                    .frame(height: Constants.dividerHeight)
                button(extra.title, systemImage: extra.systemImage, label: nil, action: extra.perform)
                    .disabled(!extra.isEnabled)
            }
        }
        .padding(.horizontal, Constants.capsulePadding)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator, lineWidth: Constants.borderWidth))
        .shadow(color: .black.opacity(Constants.shadowOpacity), radius: Constants.shadowRadius, y: 1)
        .disabled(isDisabled)
    }

    private func button(
        _ title: String,
        systemImage: String,
        label: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(title)
        .accessibilityLabel(label ?? title)
    }
}

private enum Constants {
    static let buttonSize: CGFloat = 26
    static let capsulePadding: CGFloat = 4
    static let dividerHeight: CGFloat = 14
    static let borderWidth: CGFloat = 0.5
    static let shadowOpacity: Double = 0.12
    static let shadowRadius: CGFloat = 3
}
