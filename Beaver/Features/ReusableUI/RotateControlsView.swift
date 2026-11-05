import BeaverCore
import SwiftUI

/// The pair of round rotate buttons on a card. Reports the direction instead of owning the angle,
/// so the caller can route the change through the reactor.
struct RotateControlsView: View {
    /// The file name, so VoiceOver says what turns ("Rotate photo.png left").
    var subject: String?
    var isDisabled = false
    let onRotate: (RotationDirection) -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Layout.rotateButtonSpacing) {
            rotateButton(
                direction: .left,
                icon: DesignSystem.Icons.rotateLeftIconFill,
                help: DesignSystem.Accessibility.rotateLeft,
                label: subject.map(DesignSystem.Accessibility.rotateLeft) ?? DesignSystem.Accessibility.rotateLeft
            )
            rotateButton(
                direction: .right,
                icon: DesignSystem.Icons.rotateRightIconFill,
                help: DesignSystem.Accessibility.rotateRight,
                label: subject.map(DesignSystem.Accessibility.rotateRight) ?? DesignSystem.Accessibility.rotateRight
            )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? DesignSystem.Opacity.disabled : 1)
    }

    private func rotateButton(
        direction: RotationDirection,
        icon: String,
        help: String,
        label: String
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: DesignSystem.Layout.rotateAnimationDuration)) {
                onRotate(direction)
            }
        } label: {
            Image(systemName: icon)
                .scaledFont(size: DesignSystem.Layout.rotateIconSize, weight: .semibold)
                .foregroundColor(.white)
                .frame(
                    width: DesignSystem.Layout.rotateButtonSize,
                    height: DesignSystem.Layout.rotateButtonSize
                )
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.rotateButtonColor)
                        .shadow(
                            color: DesignSystem.Colors.rotateButtonColor
                                .opacity(DesignSystem.Shadows.iconButtonOpacity),
                            radius: DesignSystem.Shadows.iconButtonRadius,
                            x: 0,
                            y: DesignSystem.Shadows.iconButtonOffset
                        )
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(label)
    }
}
