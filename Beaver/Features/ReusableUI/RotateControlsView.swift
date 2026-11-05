import BeaverCore
import SwiftUI

struct RotateControlsView: View {
    @Binding var rotationAngle: RotationAngle

    var body: some View {
        HStack(spacing: DesignSystem.Layout.rotateButtonSpacing) {
            rotateButton(
                direction: .left,
                icon: DesignSystem.Icons.rotateLeftIconFill,
                label: DesignSystem.Accessibility.rotateLeft
            )
            rotateButton(
                direction: .right,
                icon: DesignSystem.Icons.rotateRightIconFill,
                label: DesignSystem.Accessibility.rotateRight
            )
        }
    }

    private func rotateButton(
        direction: RotationDirection,
        icon: String,
        label: String
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: DesignSystem.Layout.rotateAnimationDuration)) {
                rotationAngle = rotationAngle.rotated(direction)
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
        .help(label)
        .accessibilityLabel(label)
    }
}
