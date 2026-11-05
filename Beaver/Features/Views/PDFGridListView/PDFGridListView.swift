import AsyncReactor
import SwiftUI

struct PDFGridListView: View {
    @EnvironmentObject private var reactor: BeaverReactor

    @ActionBinding(
        BeaverReactor.self,
        keyPath: \.selectedPDFs,
        action: BeaverReactor.SyncAction.didUserSelectPDF
    )
    private var selectedPDFs: [PDFItem]

    private let columns = [
        GridItem(.adaptive(minimum: 400))
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
            .fileDrop(.pdf) { urls in
                reactor.send(.addPDFs(urls))
            }
        }
        .processingOverlay(reactor.state.activity)
        .discardConfirmation(reactor: reactor)
        .exportAlert(reactor: reactor)
    }

    @ViewBuilder
    private func headerView() -> some View {
        VStack(spacing: DesignSystem.Spacing.headerSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DesignSystem.Text.pdfDocumentsTitle)
                        .accessibilityAddTraits(.isHeader)
                        .scaledFont(size: DesignSystem.Typography.titleFontSize, weight: .bold, design: .rounded)
                        .foregroundColor(DesignSystem.Colors.titleColor)

                    Text(DesignSystem.Text.pdfFilesLoadedCount(selectedPDFs.count))
                        .scaledFont(size: DesignSystem.Typography.subtitleFontSize, weight: .medium, design: .rounded)
                        .foregroundColor(DesignSystem.Colors.subtitleColor)
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
                        title: DesignSystem.ButtonLabels.addPDF,
                        color: DesignSystem.Colors.addButtonColor
                    ) {
                        reactor.send(.selectPDF)
                    }

                    HeaderActionButton(
                        icon: DesignSystem.Icons.splitButtonIcon,
                        title: DesignSystem.ButtonLabels.splitPDFs,
                        color: DesignSystem.Colors.splitButtonColor
                    ) {
                        reactor.send(.splitPDF(selectedPDFs.map(\.url)))
                    }

                    HeaderActionButton(
                        icon: DesignSystem.Icons.mergeButtonIcon,
                        title: DesignSystem.ButtonLabels.mergePDFs,
                        color: DesignSystem.Colors.mergeButtonColor
                    ) {
                        reactor.send(.mergePDF(selectedPDFs.map(\.url)))
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
                ForEach($selectedPDFs) { $pdf in
                    VStack(spacing: 0) {
                        HStack {
                            RotateControlsView(rotationAngle: $pdf.rotationAngle)

                            Spacer()

                            DeleteIconButton(
                                accessibilityLabel: DesignSystem.Accessibility.delete(pdf.url.lastPathComponent)
                            ) {
                                reactor.send(.deletePDF(pdf.id))
                            }
                        }
                        .padding(.horizontal, Constants.cardHorizontalPadding)
                        .padding(.top, Constants.cardTopPadding)
                        .padding(.bottom, Constants.cardMiddlePadding)

                        ZStack {
                            RoundedRectangle(
                                cornerRadius: DesignSystem.CornerRadius.pdfContainer,
                                style: .continuous
                            )
                            .fill(DesignSystem.Colors.pdfContainerBackgroundColor)
                            .frame(height: Constants.pdfContainerHeight)

                            PDFKitView(
                                url: pdf.url,
                                rotationAngle: $pdf.rotationAngle
                            )
                            .frame(height: Constants.pdfViewHeight)
                            .accessibilityLabel(DesignSystem.Accessibility.preview(pdf.url.lastPathComponent))
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: DesignSystem.CornerRadius.pdfView,
                                    style: .continuous
                                )
                            )
                            .shadow(
                                color: .black.opacity(Constants.pdfViewShadowOpacity),
                                radius: DesignSystem.Shadows.defaultRadius,
                                x: 0,
                                y: DesignSystem.Shadows.backgroundOffset
                            )
                        }
                        .padding(.horizontal, Constants.cardHorizontalPadding)

                        VStack(spacing: Constants.textSpacing) {
                            Text(pdf.url.lastPathComponent)
                                .scaledFont(size: DesignSystem.Typography.fileNameFontSize, weight: .semibold, design: .rounded)
                                .foregroundColor(DesignSystem.Colors.titleColor)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            Text(DesignSystem.Text.pdfDocument)
                                .scaledFont(size: DesignSystem.Typography.documentTypeFontSize, weight: .medium, design: .rounded)
                                .foregroundColor(DesignSystem.Colors.subtitleColor)
                        }
                        .padding(.horizontal, Constants.cardHorizontalPadding)
                        .padding(.vertical, Constants.cardBottomPadding)
                    }
                    .background(
                        RoundedRectangle(
                            cornerRadius: DesignSystem.CornerRadius.card,
                            style: .continuous
                        )
                        .fill(DesignSystem.Colors.cardSurface)
                    )
                }
            }
            .padding(DesignSystem.Spacing.contentPadding)
        }
    }
}

private enum Constants {
    static let circleSize: CGFloat = 400
    static let circleOffset = CGSize(width: -250, height: -200)

    static let gridSpacing: CGFloat = 20
    static let cardHorizontalPadding: CGFloat = 20
    static let cardTopPadding: CGFloat = 20
    static let cardMiddlePadding: CGFloat = 16
    static let cardBottomPadding: CGFloat = 16

    static let pdfContainerHeight: CGFloat = 400
    static let pdfViewHeight: CGFloat = 380
    static let pdfViewShadowOpacity: Double = 0.1

    static let textSpacing: CGFloat = 8
}
