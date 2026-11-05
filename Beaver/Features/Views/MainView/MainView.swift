import AsyncReactor
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var reactor: BeaverReactor

    @ActionBinding(
        BeaverReactor.self,
        keyPath: \.screen,
        action: BeaverReactor.SyncAction.didChangeScreen
    )
    private var screen: AppScreen

    @ActionBinding(
        BeaverReactor.self,
        keyPath: \.isFileImporterPresented,
        action: BeaverReactor.SyncAction.didChangeFileImporterPresented
    )
    private var isFileImporterPresented: Bool

    var body: some View {
        Group {
            switch screen {
            case .menu:
                menuView()
            case .pdfWorkflow:
                PDFGridListView()
            case .imageWorkflow:
                ImageToPDFView()
            }
        }
        .focusedSceneObject(reactor)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: reactor.state.fileImport?.allowedContentTypes ?? [],
            allowsMultipleSelection: reactor.state.fileImport?.allowsMultipleSelection ?? false
        ) { result in
            switch result {
            case .success(let urls):
                reactor.send(.didImportFiles(urls))
            case .failure(let error):
                reactor.send(.didFailFileImport(error.localizedDescription))
            }
        }
        .modifier(FileDialogConfirmationLabel(label: reactor.state.fileImport?.confirmationLabel))
    }

    private func menuView() -> some View {
        BackgroundShellView(
            circles: [
                BackgroundShellView.DecorativeCircle(
                    size: Constants.leftCircleSize,
                    offset: Constants.leftCircleOffset,
                    blurRadius: Constants.circleBlurRadius,
                    startColor: DesignSystem.Colors.primaryGradientStart,
                    endColor: DesignSystem.Colors.primaryGradientEnd,
                    startOpacity: Constants.leftCircleStartOpacity,
                    endOpacity: Constants.leftCircleEndOpacity,
                    startPoint: .center,
                    endPoint: .trailing
                ),
                BackgroundShellView.DecorativeCircle(
                    size: Constants.rightCircleSize,
                    offset: Constants.rightCircleOffset,
                    blurRadius: Constants.circleBlurRadius,
                    startColor: DesignSystem.Colors.primaryGradientMiddle,
                    endColor: DesignSystem.Colors.primaryGradientStart,
                    startOpacity: Constants.rightCircleStartOpacity,
                    endOpacity: Constants.rightCircleEndOpacity,
                    startPoint: .center,
                    endPoint: .leading
                )
            ]
        ) {
            VStack(spacing: Constants.mainVerticalSpacing) {
                VStack(spacing: Constants.titleVerticalSpacing) {
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
                                width: Constants.iconCircleSize,
                                height: Constants.iconCircleSize
                            )
                            .shadow(
                                color: DesignSystem.Colors.primaryGradientStart
                                    .opacity(Constants.iconShadowOpacity),
                                radius: Constants.iconShadowRadius,
                                x: Constants.iconShadowOffset.width,
                                y: Constants.iconShadowOffset.height
                            )

                        Image(.beaverIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(
                                width: Constants.iconSize,
                                height: Constants.iconSize
                            )
                            .foregroundColor(.white)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: Constants.titleSubtitleSpacing) {
                        Text(DesignSystem.Text.beaverTitle)
                            .accessibilityAddTraits(.isHeader)
                            .scaledFont(size: Constants.titleFontSize, weight: .bold, design: .rounded)
                            .foregroundColor(DesignSystem.Colors.titleColor)

                        Text(DesignSystem.Text.beaverSubtitle)
                            .scaledFont(size: Constants.subtitleFontSize, weight: .medium, design: .rounded)
                            .foregroundColor(DesignSystem.Colors.subtitleColor)
                    }
                }
                .padding(.top, Constants.topPadding)

                HStack(spacing: Constants.buttonsHorizontalSpacing) {
                    menuButton(
                        description: DesignSystem.Text.pdfButtonDescription,
                        icon: DesignSystem.Icons.pdfButtonIcon,
                        acceptsPDF: true,
                        action: { reactor.send(.selectPDF) }
                    )

                    menuButton(
                        description: DesignSystem.Text.imageButtonDescription,
                        icon: DesignSystem.Icons.imageButtonIcon,
                        acceptsPDF: false,
                        action: { reactor.send(.selectImages) }
                    )
                }
                .padding(.bottom, Constants.bottomPadding)
            }
        }
    }

    private func menuButton(
        description: String,
        icon: String,
        acceptsPDF: Bool,
        action: @escaping () -> Void
    ) -> some View {
        GridMenuButtonView(
            description: description,
            icon: icon,
            action: action
        )
        .fileDrop(acceptsPDF ? .pdf : .image) { urls in
            reactor.send(acceptsPDF ? .addPDFs(urls) : .addImages(urls))
        }
    }
}

/// Sets the importer's confirm button where the OS supports it (macOS 15, iOS 18).
private struct FileDialogConfirmationLabel: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if #available(macOS 15.0, iOS 18.0, *) {
            content.fileDialogConfirmationLabel(label.map { Text($0) })
        } else {
            content
        }
    }
}

private enum Constants {
    static let leftCircleSize: CGFloat = 300
    static let rightCircleSize: CGFloat = 200
    static let leftCircleOffset = CGSize(width: -200, height: -150)
    static let rightCircleOffset = CGSize(width: 300, height: 200)
    static let leftCircleStartOpacity: Double = 0.1
    static let leftCircleEndOpacity: Double = 0.05
    static let rightCircleStartOpacity: Double = 0.08
    static let rightCircleEndOpacity: Double = 0.03
    static let circleBlurRadius: CGFloat = 1

    static let iconCircleSize: CGFloat = 120
    static let iconSize: CGFloat = 80
    static let iconShadowOpacity: Double = 0.3
    static let iconShadowRadius: CGFloat = 20
    static let iconShadowOffset = CGSize(width: 0, height: 10)

    static let titleFontSize: CGFloat = 48
    static let subtitleFontSize: CGFloat = 18

    static let mainVerticalSpacing: CGFloat = 40
    static let titleVerticalSpacing: CGFloat = 20
    static let titleSubtitleSpacing: CGFloat = 8
    static let buttonsHorizontalSpacing: CGFloat = 40
    static let topPadding: CGFloat = 40
    static let bottomPadding: CGFloat = 60
}
