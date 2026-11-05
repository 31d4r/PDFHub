import SwiftUI

struct DeleteIconButton: View {
    var helpText: String?
    /// What VoiceOver announces, e.g. "Remove report.pdf".
    var accessibilityLabel: String = DesignSystem.Accessibility.remove
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: DesignSystem.Icons.deleteIconFill)
                .scaledFont(size: DesignSystem.Layout.deleteIconSize, weight: .semibold)
                .foregroundColor(.white)
                .frame(
                    width: DesignSystem.Layout.deleteButtonSize,
                    height: DesignSystem.Layout.deleteButtonSize
                )
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.destructiveButtonColor)
                        .shadow(
                            color: DesignSystem.Colors.destructiveButtonColor
                                .opacity(DesignSystem.Shadows.iconButtonOpacity),
                            radius: DesignSystem.Shadows.iconButtonRadius,
                            x: 0,
                            y: DesignSystem.Shadows.iconButtonOffset
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .modifier(OptionalHelpModifier(helpText: helpText))
    }
}

private struct OptionalHelpModifier: ViewModifier {
    let helpText: String?

    func body(content: Content) -> some View {
        if let helpText {
            content.help(helpText)
        } else {
            content
        }
    }
}
