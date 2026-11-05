import SwiftUI

struct BackgroundShellView<Content: View>: View {
    struct DecorativeCircle {
        let size: CGFloat
        let offset: CGSize
        let blurRadius: CGFloat
        let startColorHex: String
        let endColorHex: String
        let startOpacity: Double
        let endOpacity: Double
        let startPoint: UnitPoint
        let endPoint: UnitPoint
    }

    private let circles: [DecorativeCircle]
    private let content: Content

    init(
        circles: [DecorativeCircle] = [
            DecorativeCircle(
                size: 400,
                offset: CGSize(width: -250, height: -200),
                blurRadius: DesignSystem.Layout.decorativeCircleBlurRadius,
                startColorHex: DesignSystem.Colors.primaryGradientStart,
                endColorHex: DesignSystem.Colors.primaryGradientEnd,
                startOpacity: DesignSystem.Opacity.circleStart,
                endOpacity: DesignSystem.Opacity.circleEnd,
                startPoint: .center,
                endPoint: .trailing
            )
        ],
        @ViewBuilder content: () -> Content
    ) {
        self.circles = circles
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: DesignSystem.Colors.backgroundGradientStart),
                    Color(hex: DesignSystem.Colors.backgroundGradientEnd)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ForEach(Array(circles.enumerated()), id: \.offset) { _, circle in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: circle.startColorHex).opacity(circle.startOpacity),
                                Color(hex: circle.endColorHex).opacity(circle.endOpacity)
                            ],
                            startPoint: circle.startPoint,
                            endPoint: circle.endPoint
                        )
                    )
                    .frame(width: circle.size, height: circle.size)
                    .offset(circle.offset)
                    .blur(radius: circle.blurRadius)
                    .accessibilityHidden(true)
            }

            content
        }
    }
}
