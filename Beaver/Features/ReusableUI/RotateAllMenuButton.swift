import BeaverCore
import SwiftUI

/// An icon-only header button that opens Rotate All Left / Rotate All Right.
/// Icon-only so the header still fits at the minimum window width.
struct RotateAllMenuButton: View {
    var isDisabled = false
    let onRotate: (RotationDirection) -> Void

    var body: some View {
        Menu {
            Button {
                rotate(.left)
            } label: {
                Label(DesignSystem.Commands.rotateAllLeft, systemImage: DesignSystem.Icons.rotateLeftIcon)
            }

            Button {
                rotate(.right)
            } label: {
                Label(DesignSystem.Commands.rotateAllRight, systemImage: DesignSystem.Icons.rotateRightIcon)
            }
        } label: {
            Image(systemName: DesignSystem.Icons.rotateRightIcon)
                .scaledFont(size: DesignSystem.Layout.buttonIconSize, weight: .semibold)
                .foregroundColor(isDisabled ? .gray : .white)
                .padding(.horizontal, DesignSystem.Spacing.buttonVerticalPadding)
                .padding(.vertical, DesignSystem.Spacing.buttonVerticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                        .fill(isDisabled ? Color.gray.opacity(0.3) : DesignSystem.Colors.rotateButtonColor)
                        .shadow(
                            color: isDisabled ? .clear : DesignSystem.Colors.rotateButtonColor
                                .opacity(DesignSystem.Shadows.defaultOpacity),
                            radius: DesignSystem.Shadows.defaultRadius,
                            x: DesignSystem.Shadows.defaultOffset.width,
                            y: DesignSystem.Shadows.defaultOffset.height
                        )
                )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(isDisabled)
        .help(DesignSystem.ButtonLabels.rotateAll)
        .accessibilityLabel(DesignSystem.ButtonLabels.rotateAll)
    }

    private func rotate(_ direction: RotationDirection) {
        withAnimation(.easeInOut(duration: DesignSystem.Layout.rotateAnimationDuration)) {
            onRotate(direction)
        }
    }
}
