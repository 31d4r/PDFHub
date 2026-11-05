import AsyncReactor
import SwiftUI

struct ImageToPDFView: View {
    @EnvironmentObject private var reactor: BeaverReactor

    @ActionBinding(
        BeaverReactor.self,
        keyPath: \.selectedImages,
        action: BeaverReactor.SyncAction.didUserSelectImages
    )
    private var selectedImages: [ImageItem]

    private let columns = [
        GridItem(
            .adaptive(minimum: 200, maximum: 400),
            spacing: 20
        )
    ]

    var body: some View {
        BackgroundShellView(
            circles: [
                BackgroundShellView.DecorativeCircle(
                    size: Constants.circleSize,
                    offset: Constants.circleOffset,
                    blurRadius: DesignSystem.Layout.decorativeCircleBlurRadius,
                    startColorHex: DesignSystem.Colors.primaryGradientStart,
                    endColorHex: DesignSystem.Colors.primaryGradientEnd,
                    startOpacity: DesignSystem.Opacity.circleStart,
                    endOpacity: DesignSystem.Opacity.circleEnd,
                    startPoint: .center,
                    endPoint: .trailing
                )
            ]
        ) {
            VStack(spacing: 0) {
                headerView()
                content()
            }
        }
        .exportAlert(reactor: reactor)
    }

    private func headerView() -> some View {
        VStack(spacing: DesignSystem.Spacing.headerSpacing) {
            HStack {
                VStack(
                    alignment: .leading,
                    spacing: Constants.headerVerticalSpacing
                ) {
                    HStack(spacing: Constants.headerHorizontalSpacing) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(hex: DesignSystem.Colors.primaryGradientStart),
                                            Color(hex: DesignSystem.Colors.primaryGradientEnd)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(
                                    width: Constants.headerIconSize,
                                    height: Constants.headerIconSize
                                )

                            Image(systemName: DesignSystem.Icons.headerIcon)
                                .font(
                                    .system(
                                        size: Constants.headerIconImageSize,
                                        weight: .semibold
                                    )
                                )
                                .foregroundColor(.white)
                        }

                        VStack(
                            alignment: .leading,
                            spacing: Constants.headerTextSpacing
                        ) {
                            Text(DesignSystem.Text.imagesToPDFTitle)
                                .font(
                                    .system(
                                        size: DesignSystem.Typography.titleFontSize,
                                        weight: .bold,
                                        design: .rounded
                                    )
                                )
                                .foregroundColor(Color(hex: DesignSystem.Colors.titleColor))

                            Text(DesignSystem.Text.imagesReadyCount(selectedImages.count))
                                .font(
                                    .system(
                                        size: DesignSystem.Typography.subtitleFontSize,
                                        weight: .medium,
                                        design: .rounded
                                    )
                                )
                                .foregroundColor(Color(hex: DesignSystem.Colors.subtitleColor))
                        }
                    }
                }

                Spacer()

                HStack(spacing: DesignSystem.Spacing.buttonSpacing) {
                    HeaderActionButton(
                        icon: DesignSystem.Icons.backButtonIcon,
                        title: DesignSystem.ButtonLabels.back,
                        color: Color(hex: DesignSystem.Colors.addButtonColor)
                    ) {
                        reactor.send(.goBack)
                    }

                    HeaderActionButton(
                        icon: DesignSystem.Icons.addButtonIcon,
                        title: DesignSystem.ButtonLabels.addImages,
                        color: Color(hex: DesignSystem.Colors.addButtonColor)
                    ) {
                        reactor.send(.selectImages)
                    }

                    HeaderActionButton(
                        icon: DesignSystem.Icons.convertButtonIcon,
                        title: DesignSystem.ButtonLabels.convertToPDF,
                        color: Color(hex: DesignSystem.Colors.convertButtonColor),
                        isDisabled: selectedImages.isEmpty
                    ) {
                        reactor.send(.convertImagesToPDF)
                    }

                    HeaderActionButton(
                        icon: DesignSystem.Icons.clearButtonIcon,
                        title: DesignSystem.ButtonLabels.clearAll,
                        color: Color(hex: DesignSystem.Colors.destructiveButtonColor)
                    ) {
                        reactor.send(.clearImages)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.headerHorizontalPadding)
            .padding(.top, DesignSystem.Spacing.headerTopPadding)

            HStack {
                ForEach(
                    0 ..< min(selectedImages.count, Constants.maxVisibleDots),
                    id: \.self
                ) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: DesignSystem.Colors.primaryGradientStart),
                                    Color(hex: DesignSystem.Colors.primaryGradientEnd)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(
                            width: Constants.dotSize,
                            height: Constants.dotSize
                        )
                        .scaleEffect(
                            index < selectedImages.count
                                ? Constants.activeDotScale
                                : Constants.inactiveDotScale
                        )
                        .opacity(
                            index < selectedImages.count
                                ? Constants.activeDotOpacity
                                : Constants.inactiveDotOpacity
                        )
                }

                if selectedImages.count > Constants.maxVisibleDots {
                    Text("+\(selectedImages.count - Constants.maxVisibleDots)")
                        .font(
                            .system(
                                size: DesignSystem.Typography.counterFontSize,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundColor(Color(hex: DesignSystem.Colors.subtitleColor))
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.headerHorizontalPadding)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: DesignSystem.Colors.primaryGradientStart)
                                .opacity(DesignSystem.Opacity.separatorStart),
                            Color(hex: DesignSystem.Colors.primaryGradientEnd)
                                .opacity(DesignSystem.Opacity.separatorEnd)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: DesignSystem.Layout.separatorHeight)
                .padding(.horizontal, DesignSystem.Spacing.headerHorizontalPadding)
        }
        .padding(.bottom, DesignSystem.Spacing.headerBottomPadding)
    }

    private func content() -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Constants.gridSpacing) {
                ForEach(selectedImages) { item in
                    VStack {
                        HStack {
                            Spacer()

                            DeleteIconButton(helpText: "Delete This Image") {
                                reactor.send(.deleteImage(item.id))
                            }
                        }
                        .padding(DesignSystem.Spacing.contentPadding)

                        Image(nsImage: item.image)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                maxWidth: Constants.imageMaxWidth,
                                maxHeight: Constants.imageMaxHeight
                            )
                            .padding(DesignSystem.Spacing.contentPadding)
                    }
                    .background(
                        RoundedRectangle(
                            cornerRadius: DesignSystem.CornerRadius.cardSmall,
                            style: .continuous
                        )
                        .fill(.white)
                        .shadow(
                            color: .black.opacity(Constants.cardShadowOpacity),
                            radius: Constants.cardShadowRadius,
                            x: 0,
                            y: Constants.cardShadowOffset
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: DesignSystem.CornerRadius.cardSmall,
                            style: .continuous
                        )
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: DesignSystem.Colors.primaryGradientStart)
                                        .opacity(DesignSystem.Opacity.cardBorderStart),
                                    Color(hex: DesignSystem.Colors.primaryGradientEnd)
                                        .opacity(DesignSystem.Opacity.cardBorderEnd)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: Constants.cardBorderWidth
                        )
                    )
                }
            }
            .padding(DesignSystem.Spacing.contentPadding)
        }
    }
}

private enum Constants {
    static let circleSize: CGFloat = 350
    static let circleOffset = CGSize(width: 300, height: -150)

    static let headerIconSize: CGFloat = 40
    static let headerIconImageSize: CGFloat = 18
    static let headerHorizontalSpacing: CGFloat = 12
    static let headerVerticalSpacing: CGFloat = 4
    static let headerTextSpacing: CGFloat = 2

    static let dotSize: CGFloat = 8
    static let maxVisibleDots = 10
    static let activeDotScale: CGFloat = 1.0
    static let inactiveDotScale: CGFloat = 0.5
    static let activeDotOpacity: Double = 1.0
    static let inactiveDotOpacity: Double = 0.3

    static let gridSpacing: CGFloat = 20
    static let imageMaxWidth: CGFloat = 400
    static let imageMaxHeight: CGFloat = 400
    static let cardBorderWidth: CGFloat = 1
    static let cardShadowOpacity: Double = 0.08
    static let cardShadowRadius: CGFloat = 12
    static let cardShadowOffset: CGFloat = 4
}
