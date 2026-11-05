import AsyncReactor
import SwiftUI

struct PDFGridListView: View {
    @EnvironmentObject private var reactor: BeaverReactor

    @ActionBinding(
        BeaverReactor.self,
        keyPath: \.selectedPDFs,
        action: BeaverReactor.SyncAction.didUserSelectPDF
    )
    private var selectedPDFs: [PDF]

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
        .processingOverlay(reactor.state.activity)
        .exportAlert(reactor: reactor)
    }

    @ViewBuilder
    private func headerView() -> some View {
        VStack(spacing: DesignSystem.Spacing.headerSpacing) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DesignSystem.Text.pdfDocumentsTitle)
                        .font(
                            .system(
                                size: DesignSystem.Typography.titleFontSize,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .foregroundColor(Color(hex: DesignSystem.Colors.titleColor))

                    Text(DesignSystem.Text.pdfFilesLoadedCount(selectedPDFs.count))
                        .font(
                            .system(
                                size: DesignSystem.Typography.subtitleFontSize,
                                weight: .medium,
                                design: .rounded
                            )
                        )
                        .foregroundColor(Color(hex: DesignSystem.Colors.subtitleColor))
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
                        title: DesignSystem.ButtonLabels.addPDF,
                        color: Color(hex: DesignSystem.Colors.addButtonColor)
                    ) {
                        reactor.send(.selectPDF)
                    }

                    HeaderActionButton(
                        icon: DesignSystem.Icons.splitButtonIcon,
                        title: DesignSystem.ButtonLabels.splitPDFs,
                        color: Color(hex: DesignSystem.Colors.splitButtonColor)
                    ) {
                        reactor.send(.splitPDF(selectedPDFs.map(\.pdfURL)))
                    }

                    HeaderActionButton(
                        icon: DesignSystem.Icons.mergeButtonIcon,
                        title: DesignSystem.ButtonLabels.mergePDFs,
                        color: Color(hex: DesignSystem.Colors.mergeButtonColor)
                    ) {
                        reactor.send(.mergePDF(selectedPDFs.map(\.pdfURL)))
                    }

                    HeaderActionButton(
                        icon: DesignSystem.Icons.clearButtonIcon,
                        title: DesignSystem.ButtonLabels.clearAll,
                        color: Color(hex: DesignSystem.Colors.destructiveButtonColor)
                    ) {
                        reactor.send(.clearPDFs)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.headerHorizontalPadding)
            .padding(.top, DesignSystem.Spacing.headerTopPadding)

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
                ForEach($selectedPDFs) { $pdf in
                    VStack(spacing: 0) {
                        HStack {
                            RotateControlsView(rotationAngle: $pdf.rotationAngle)

                            Spacer()

                            DeleteIconButton {
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
                            .fill(Color(hex: DesignSystem.Colors.pdfContainerBackgroundColor))
                            .frame(height: Constants.pdfContainerHeight)

                            PDFKitView(
                                url: pdf.pdfURL,
                                rotationAngle: $pdf.rotationAngle
                            )
                            .frame(height: Constants.pdfViewHeight)
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
                            Text(pdf.pdfURL.lastPathComponent)
                                .font(
                                    .system(
                                        size: DesignSystem.Typography.fileNameFontSize,
                                        weight: .semibold,
                                        design: .rounded
                                    )
                                )
                                .foregroundColor(Color(hex: DesignSystem.Colors.titleColor))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            Text(DesignSystem.Text.pdfDocument)
                                .font(
                                    .system(
                                        size: DesignSystem.Typography.documentTypeFontSize,
                                        weight: .medium,
                                        design: .rounded
                                    )
                                )
                                .foregroundColor(Color(hex: DesignSystem.Colors.subtitleColor))
                        }
                        .padding(.horizontal, Constants.cardHorizontalPadding)
                        .padding(.vertical, Constants.cardBottomPadding)
                    }
                    .background(
                        RoundedRectangle(
                            cornerRadius: DesignSystem.CornerRadius.card,
                            style: .continuous
                        )
                        .fill(.white)
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
