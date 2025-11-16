import SwiftUI

struct GridMenuButtonView: View {
    var description: String
    var icon: String
    var action: () -> Void
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: Constants.verticalSpacing) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: DesignSystem.Colors.primaryGradientStart),
                                    Color(hex: DesignSystem.Colors.primaryGradientMiddle),
                                    Color(hex: DesignSystem.Colors.primaryGradientEnd)
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
                            color: Color(hex: DesignSystem.Colors.primaryGradientStart).opacity(DesignSystem.Shadows.defaultOpacity),
                            radius: isPressed ? Constants.shadowRadiusPressed : Constants.shadowRadius,
                            x: 0,
                            y: isPressed ? Constants.shadowOffsetPressed : Constants.shadowOffset
                        )

                    Image(systemName: icon)
                        .font(
                            .system(
                                size: Constants.iconSize,
                                weight: .medium
                            )
                        )
                        .foregroundColor(.white)
                }
                .scaleEffect(isPressed ? Constants.pressedScale : (isHovered ? Constants.hoveredScale : Constants.normalScale))

                Text(description)
                    .font(
                        .system(
                            size: Constants.fontSize,
                            weight: .medium,
                            design: .rounded
                        )
                    )
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: DesignSystem.Colors.titleColor))
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
                .fill(.white)
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
                            Color(hex: DesignSystem.Colors.primaryGradientStart).opacity(Constants.gradientBorderStartOpacity),
                            Color(hex: DesignSystem.Colors.primaryGradientEnd).opacity(Constants.gradientBorderEndOpacity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHovered ? Constants.borderWidthHovered : Constants.borderWidthNormal
                )
            )
            .scaleEffect(isPressed ? Constants.buttonPressedScale : Constants.normalScale)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: Constants.hoverAnimationDuration)) {
                isHovered = hovering
            }
        }
        .pressEvents {
            withAnimation(.easeInOut(duration: Constants.pressAnimationDuration)) {
                isPressed = true
            }
        } onRelease: {
            withAnimation(.easeInOut(duration: Constants.pressAnimationDuration)) {
                isPressed = false
            }
        }
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
