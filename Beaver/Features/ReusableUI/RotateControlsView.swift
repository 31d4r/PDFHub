import SwiftUI

struct RotateControlsView: View {
    @Binding var rotationAngle: RotationAngle

    var body: some View {
        HStack(spacing: DesignSystem.Layout.rotateButtonSpacing) {
            rotateButton(
                direction: .left,
                icon: DesignSystem.Icons.rotateLeftIconFill
            )
            rotateButton(
                direction: .right,
                icon: DesignSystem.Icons.rotateRightIconFill
            )
        }
    }

    private func rotateButton(
        direction: RotationDirection,
        icon: String
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: DesignSystem.Layout.rotateAnimationDuration)) {
                rotationAngle = rotationAngle.rotated(direction)
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Layout.rotateIconSize, weight: .semibold))
                .foregroundColor(.white)
                .frame(
                    width: DesignSystem.Layout.rotateButtonSize,
                    height: DesignSystem.Layout.rotateButtonSize
                )
                .background(
                    Circle()
                        .fill(Color(hex: DesignSystem.Colors.rotateButtonColor))
                        .shadow(
                            color: Color(hex: DesignSystem.Colors.rotateButtonColor)
                                .opacity(DesignSystem.Shadows.iconButtonOpacity),
                            radius: DesignSystem.Shadows.iconButtonRadius,
                            x: 0,
                            y: DesignSystem.Shadows.iconButtonOffset
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
