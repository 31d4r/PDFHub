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
                                    Color(hex: Constants.gradientStartColor),
                                    Color(hex: Constants.gradientMiddleColor),
                                    Color(hex: Constants.gradientEndColor)
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
                            color: Color(hex: Constants.gradientStartColor).opacity(Constants.shadowOpacity),
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
                    .foregroundColor(Color(hex: Constants.textColor))
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
                    color: .black.opacity(Constants.backgroundShadowOpacity),
                    radius: isPressed ? Constants.backgroundShadowRadiusPressed : Constants.backgroundShadowRadius,
                    x: 0,
                    y: isPressed ? Constants.backgroundShadowOffsetPressed : Constants.backgroundShadowOffset
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
                            Color(hex: Constants.gradientStartColor).opacity(Constants.gradientBorderStartOpacity),
                            Color(hex: Constants.gradientEndColor).opacity(Constants.gradientBorderEndOpacity)
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
    /// Colors
    static let gradientStartColor = "FF6B35"
    static let gradientMiddleColor = "F7931E"
    static let gradientEndColor = "FFD23F"
    static let textColor = "2D3748"
    
    /// Dimensions
    static let circleSize: CGFloat = 100
    static let buttonWidth: CGFloat = 280
    static let buttonHeight: CGFloat = 260
    static let iconSize: CGFloat = 50
    static let cornerRadius: CGFloat = 24
    
    /// Spacing and Padding
    static let verticalSpacing: CGFloat = 20
    static let verticalPadding: CGFloat = 30
    static let horizontalPadding: CGFloat = 20
    static let textHorizontalPadding: CGFloat = 16
    
    /// Shadow Properties
    static let shadowOpacity: Double = 0.3
    static let shadowRadius: CGFloat = 15
    static let shadowRadiusPressed: CGFloat = 8
    static let shadowOffset: CGFloat = 8
    static let shadowOffsetPressed: CGFloat = 4
    static let backgroundShadowOpacity: Double = 0.08
    static let backgroundShadowRadius: CGFloat = 12
    static let backgroundShadowRadiusPressed: CGFloat = 5
    static let backgroundShadowOffset: CGFloat = 6
    static let backgroundShadowOffsetPressed: CGFloat = 2
    
    /// Scale Effects
    static let pressedScale: CGFloat = 0.95
    static let hoveredScale: CGFloat = 1.05
    static let normalScale: CGFloat = 1.0
    static let buttonPressedScale: CGFloat = 0.98
    
    /// Border Properties
    static let borderWidthHovered: CGFloat = 2
    static let borderWidthNormal: CGFloat = 1
    static let gradientBorderStartOpacity: Double = 0.3
    static let gradientBorderEndOpacity: Double = 0.1
    
    /// Font Properties
    static let fontSize: CGFloat = 16
    static let lineLimit = 2
    
    /// Animation Durations
    static let hoverAnimationDuration: Double = 0.2
    static let pressAnimationDuration: Double = 0.1
}
