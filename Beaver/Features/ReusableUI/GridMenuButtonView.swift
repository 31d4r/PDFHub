import SwiftUI

struct GridMenuButtonView: View {
    var description: String
    var icon: String
    var action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(description)
        }
        .buttonStyle(GridMenuButtonStyle(icon: icon, isHovered: isHovered))
        .accessibilityLabel(description.replacingOccurrences(of: "\n", with: " "))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Constants.hoverAnimationDuration)) {
                isHovered = hovering
            }
        }
    }
}

/// Draws the menu card and reacts to the button's real pressed state.
private struct GridMenuButtonStyle: ButtonStyle {
    let icon: String
    let isHovered: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed

        VStack(spacing: Constants.verticalSpacing) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignSystem.Colors.primaryGradientStart,
                                DesignSystem.Colors.primaryGradientMiddle,
                                DesignSystem.Colors.primaryGradientEnd
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: Constants.circleSize,
                        height: Constants.circleSize
                    )
                    .shadow(
                        color: DesignSystem.Colors.primaryGradientStart.opacity(DesignSystem.Shadows.defaultOpacity),
                        radius: isPressed ? Constants.shadowRadiusPressed : Constants.shadowRadius,
                        x: 0,
                        y: isPressed ? Constants.shadowOffsetPressed : Constants.shadowOffset
                    )

                Image(systemName: icon)
                    .scaledFont(size: Constants.iconSize, weight: .medium)
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? Constants.pressedScale : (isHovered ? Constants.hoveredScale : Constants.normalScale))
            .accessibilityHidden(true)

            configuration.label
                .scaledFont(size: Constants.fontSize, weight: .medium, design: .rounded)
                .multilineTextAlignment(.center)
                .foregroundColor(DesignSystem.Colors.titleColor)
                .lineLimit(Constants.lineLimit)
                .padding(.horizontal, Constants.textHorizontalPadding)
        }
        .padding(.vertical, Constants.verticalPadding)
        .padding(.horizontal, Constants.horizontalPadding)
        .frame(
            width: Constants.buttonWidth,
            height: Constants.buttonHeight
        )
        .background(
            RoundedRectangle(
                cornerRadius: Constants.cornerRadius,
                style: .continuous
            )
            .fill(DesignSystem.Colors.cardSurface)
            .shadow(
                color: .black.opacity(DesignSystem.Shadows.backgroundOpacity),
                radius: isPressed ? Constants.backgroundShadowRadiusPressed : DesignSystem.Shadows.backgroundRadius,
                x: 0,
                y: isPressed ? Constants.backgroundShadowOffsetPressed : DesignSystem.Shadows.backgroundOffset
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: Constants.cornerRadius,
                style: .continuous
            )
            .stroke(
                LinearGradient(
                    colors: [
                        DesignSystem.Colors.primaryGradientStart.opacity(Constants.gradientBorderStartOpacity),
                        DesignSystem.Colors.primaryGradientEnd.opacity(Constants.gradientBorderEndOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isHovered ? Constants.borderWidthHovered : Constants.borderWidthNormal
            )
        )
        .contentShape(RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous))
        .scaleEffect(isPressed ? Constants.buttonPressedScale : Constants.normalScale)
        .animation(.easeInOut(duration: Constants.pressAnimationDuration), value: isPressed)
    }
}

private enum Constants {
    static let circleSize: CGFloat = 100
    static let buttonWidth: CGFloat = 280
    static let buttonHeight: CGFloat = 260
    static let iconSize: CGFloat = 50
    static let cornerRadius: CGFloat = 24
    
    static let verticalSpacing: CGFloat = 20
    static let verticalPadding: CGFloat = 30
    static let horizontalPadding: CGFloat = 20
    static let textHorizontalPadding: CGFloat = 16
    
    static let shadowRadius: CGFloat = 15
    static let shadowRadiusPressed: CGFloat = 8
    static let shadowOffset: CGFloat = 8
    static let shadowOffsetPressed: CGFloat = 4
    static let backgroundShadowRadiusPressed: CGFloat = 5
    static let backgroundShadowOffsetPressed: CGFloat = 2
    
    static let pressedScale: CGFloat = 0.95
    static let hoveredScale: CGFloat = 1.05
    static let normalScale: CGFloat = 1.0
    static let buttonPressedScale: CGFloat = 0.98
    
    static let borderWidthHovered: CGFloat = 2
    static let borderWidthNormal: CGFloat = 1
    static let gradientBorderStartOpacity: Double = 0.3
    static let gradientBorderEndOpacity: Double = 0.1
    
    static let fontSize: CGFloat = 16
    static let lineLimit = 2
    
    static let hoverAnimationDuration: Double = 0.2
    static let pressAnimationDuration: Double = 0.1
}
