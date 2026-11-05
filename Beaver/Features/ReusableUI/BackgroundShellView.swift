import SwiftUI

struct BackgroundShellView<Content: View>: View {
    struct DecorativeCircle {
        let size: CGFloat
        let offset: CGSize
        let blurRadius: CGFloat
        let startColor: Color
        let endColor: Color
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
                startColor: DesignSystem.Colors.primaryGradientStart,
                endColor: DesignSystem.Colors.primaryGradientEnd,
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
                    DesignSystem.Colors.backgroundGradientStart,
                    DesignSystem.Colors.backgroundGradientEnd
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
                                circle.startColor.opacity(circle.startOpacity),
                                circle.endColor.opacity(circle.endOpacity)
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
