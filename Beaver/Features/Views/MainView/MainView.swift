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
    }

    private func menuView() -> some View {
        BackgroundShellView(
            circles: [
                BackgroundShellView.DecorativeCircle(
                    size: Constants.leftCircleSize,
                    offset: Constants.leftCircleOffset,
                    blurRadius: Constants.circleBlurRadius,
                    startColorHex: DesignSystem.Colors.primaryGradientStart,
                    endColorHex: DesignSystem.Colors.primaryGradientEnd,
                    startOpacity: Constants.leftCircleStartOpacity,
                    endOpacity: Constants.leftCircleEndOpacity,
                    startPoint: .center,
                    endPoint: .trailing
                ),
                BackgroundShellView.DecorativeCircle(
                    size: Constants.rightCircleSize,
                    offset: Constants.rightCircleOffset,
                    blurRadius: Constants.circleBlurRadius,
                    startColorHex: DesignSystem.Colors.primaryGradientMiddle,
                    endColorHex: DesignSystem.Colors.primaryGradientStart,
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
                                        Color(hex: DesignSystem.Colors.primaryGradientStart),
                                        Color(hex: DesignSystem.Colors.primaryGradientMiddle),
                                        Color(hex: DesignSystem.Colors.primaryGradientEnd)
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
                                color: Color(hex: DesignSystem.Colors.primaryGradientStart)
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
                            .foregroundColor(Color(hex: DesignSystem.Colors.titleColor))

                        Text(DesignSystem.Text.beaverSubtitle)
                            .scaledFont(size: Constants.subtitleFontSize, weight: .medium, design: .rounded)
                            .foregroundColor(Color(hex: DesignSystem.Colors.subtitleColor))
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
        .onDrop(of: [DesignSystem.FileTypes.fileURLType], isTargeted: nil) { providers in
            handleFileDrop(
                providers: providers,
                acceptsPDF: acceptsPDF
            )
        }
    }

    private func handleFileDrop(
        providers: [NSItemProvider],
        acceptsPDF: Bool
    ) -> Bool {
        let acceptedProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(DesignSystem.FileTypes.fileURLType)
        }

        for provider in acceptedProviders {
            provider.loadItem(
                forTypeIdentifier: DesignSystem.FileTypes.fileURLType,
                options: nil
            ) { item, _ in
                guard
                    let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else { return }

                let extensionMatches: Bool
                if acceptsPDF {
                    extensionMatches = DesignSystem.FileTypes.pdfExtensions.contains(
                        url.pathExtension.lowercased()
                    )
                } else {
                    extensionMatches = SupportedImageType.contains(
                        fileExtension: url.pathExtension
                    )
                }

                guard extensionMatches else { return }

                Task {
                    await MainActor.run {
                        if acceptsPDF {
                            reactor.send(.addPDFs([url]))
                        } else {
                            reactor.send(.addImages([url]))
                        }
                    }
                }
            }
        }

        return !acceptedProviders.isEmpty
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
