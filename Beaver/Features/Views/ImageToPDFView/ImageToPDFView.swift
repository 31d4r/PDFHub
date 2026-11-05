import BeaverCore
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
                    startColor: DesignSystem.Colors.primaryGradientStart,
                    endColor: DesignSystem.Colors.primaryGradientEnd,
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
            .fileDrop(.image) { urls in
                reactor.send(.addImages(urls))
            }
        }
        .processingOverlay(reactor.state.activity)
        .discardConfirmation(reactor: reactor)
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
                                            DesignSystem.Colors.primaryGradientStart,
                                            DesignSystem.Colors.primaryGradientEnd
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
                                .scaledFont(size: Constants.headerIconImageSize, weight: .semibold)
                                .foregroundColor(.white)
                        }
                        .accessibilityHidden(true)

                        VStack(
                            alignment: .leading,
                            spacing: Constants.headerTextSpacing
                        ) {
                            Text(DesignSystem.Text.imagesToPDFTitle)
                                .accessibilityAddTraits(.isHeader)
                                .scaledFont(size: DesignSystem.Typography.titleFontSize, weight: .bold, design: .rounded)
                                .foregroundColor(DesignSystem.Colors.titleColor)

                            Text(DesignSystem.Text.imagesReadyCount(selectedImages.count))
                                .scaledFont(size: DesignSystem.Typography.subtitleFontSize, weight: .medium, design: .rounded)
                                .foregroundColor(DesignSystem.Colors.subtitleColor)
                        }
                    }
                }

                Spacer()

                HStack(spacing: DesignSystem.Spacing.buttonSpacing) {
                    HeaderActionButton(
                        icon: DesignSystem.Icons.backButtonIcon,
                        title: DesignSystem.ButtonLabels.back,
                        color: DesignSystem.Colors.addButtonColor
                    ) {
                        reactor.send(.requestDiscard(.goBack))
                    }

                    HeaderActionButton(
                        icon: DesignSystem.Icons.addButtonIcon,
                        title: DesignSystem.ButtonLabels.addImages,
                        color: DesignSystem.Colors.addButtonColor
                    ) {
                        reactor.send(.selectImages)
                    }

                    HeaderActionButton(
                        icon: DesignSystem.Icons.convertButtonIcon,
                        title: DesignSystem.ButtonLabels.convertToPDF,
                        color: DesignSystem.Colors.convertButtonColor,
                        isDisabled: selectedImages.isEmpty
                    ) {
                        reactor.send(.convertImagesToPDF)
                    }

                    HeaderActionButton(
                        icon: DesignSystem.Icons.clearButtonIcon,
                        title: DesignSystem.ButtonLabels.clearAll,
                        color: DesignSystem.Colors.destructiveButtonColor
                    ) {
                        reactor.send(.requestDiscard(.clearAll))
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.headerHorizontalPadding)
            .padding(.top, DesignSystem.Spacing.headerTopPadding)

            HStack {
                ForEach(
                    0 ..< min(selectedImages.count, Constants.maxVisibleDots),
                    id: \.self
                ) { _ in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignSystem.Colors.primaryGradientStart,
                                    DesignSystem.Colors.primaryGradientEnd
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(
                            width: Constants.dotSize,
                            height: Constants.dotSize
                        )
                }

                if selectedImages.count > Constants.maxVisibleDots {
                    Text("+\(selectedImages.count - Constants.maxVisibleDots)")
                        .scaledFont(size: DesignSystem.Typography.counterFontSize, weight: .semibold, design: .rounded)
                        .foregroundColor(DesignSystem.Colors.subtitleColor)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.headerHorizontalPadding)
            .accessibilityHidden(true)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            DesignSystem.Colors.primaryGradientStart
                                .opacity(DesignSystem.Opacity.separatorStart),
                            DesignSystem.Colors.primaryGradientEnd
                                .opacity(DesignSystem.Opacity.separatorEnd)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: DesignSystem.Layout.separatorHeight)
                .accessibilityHidden(true)
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
                            RotateControlsView(
                                subject: item.url.lastPathComponent,
                                isDisabled: reactor.state.activity != nil
                            ) { direction in
                                reactor.action(.rotateImage(id: item.id, direction: direction))
                            }

                            Spacer()

                            DeleteIconButton(
                                helpText: DesignSystem.Accessibility.deleteImageHelp,
                                accessibilityLabel: DesignSystem.Accessibility.delete(item.url.lastPathComponent)
                            ) {
                                reactor.send(.deleteImage(item.id))
                            }
                        }
                        .padding(DesignSystem.Spacing.contentPadding)

                        Image(item.preview, scale: 1, label: Text(item.url.lastPathComponent))
                            .resizable()
                            .scaledToFit()
                            .frame(
                                maxWidth: Constants.imageMaxWidth,
                                maxHeight: Constants.imageMaxHeight
                            )
                            .padding(DesignSystem.Spacing.contentPadding)
                            .accessibilityValue(DesignSystem.Accessibility.rotation(item.rotationAngle))
                    }
                    .background(
                        RoundedRectangle(
                            cornerRadius: DesignSystem.CornerRadius.cardSmall,
                            style: .continuous
                        )
                        .fill(DesignSystem.Colors.cardSurface)
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
                                    DesignSystem.Colors.primaryGradientStart
                                        .opacity(DesignSystem.Opacity.cardBorderStart),
                                    DesignSystem.Colors.primaryGradientEnd
                                        .opacity(DesignSystem.Opacity.cardBorderEnd)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: Constants.cardBorderWidth
                        )
                    )
                    .reorderableCard(
                        id: item.id,
                        index: index(of: item.id),
                        count: selectedImages.count,
                        title: item.url.lastPathComponent,
                        systemImage: DesignSystem.Icons.imageButtonIcon,
                        cornerRadius: DesignSystem.CornerRadius.cardSmall,
                        isEnabled: reactor.state.activity == nil
                    ) { id, destination in
                        reactor.action(.moveImage(id: id, to: destination))
                    }
                }
            }
            .padding(DesignSystem.Spacing.contentPadding)
        }
    }
}

private extension ImageToPDFView {
    func index(of id: UUID) -> Int {
        selectedImages.firstIndex { $0.id == id } ?? 0
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

    static let gridSpacing: CGFloat = 20
    static let imageMaxWidth: CGFloat = 400
    static let imageMaxHeight: CGFloat = 400
    static let cardBorderWidth: CGFloat = 1
    static let cardShadowOpacity: Double = 0.08
    static let cardShadowRadius: CGFloat = 12
    static let cardShadowOffset: CGFloat = 4
}
