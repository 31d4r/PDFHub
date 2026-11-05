import SwiftUI

struct HeaderActionButton: View {
    let icon: String
    let title: String
    let color: Color
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.small) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Layout.buttonIconSize, weight: .semibold))

                Text(title)
                    .font(
                        .system(
                            size: DesignSystem.Typography.buttonFontSize,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
            }
            .foregroundColor(isDisabled ? .gray : .white)
            .padding(.horizontal, DesignSystem.Spacing.buttonHorizontalPadding)
            .padding(.vertical, DesignSystem.Spacing.buttonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                    .fill(isDisabled ? Color.gray.opacity(0.3) : color)
                    .shadow(
                        color: isDisabled ? .clear : color.opacity(DesignSystem.Shadows.defaultOpacity),
                        radius: DesignSystem.Shadows.defaultRadius,
                        x: DesignSystem.Shadows.defaultOffset.width,
                        y: DesignSystem.Shadows.defaultOffset.height
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
