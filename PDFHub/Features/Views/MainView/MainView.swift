import AsyncReactor
import PDFKit
import SwiftUI

enum AppScreen {
    case menu
    case pdfViewer
    case imageConverter
}

struct MainView: View {
    @EnvironmentObject private var reactor: PDFHubReactor
    
    @ActionBinding(
        PDFHubReactor.self,
        keyPath: \.selectedPDFs,
        action: PDFHubReactor.SyncAction.didUserSelectPDF
    )
    private var selectedPDFs: [PDF]
    
    @ActionBinding(
        PDFHubReactor.self,
        keyPath: \.selectedImages,
        action: PDFHubReactor.SyncAction.didUserSelectImages
    )
    private var selectedImages: [NSImage]
    
    private var currentScreen: AppScreen {
        switch (selectedImages.isEmpty, selectedPDFs.isEmpty) {
        case (false, _): return .imageConverter
        case (_, false): return .pdfViewer
        default: return .menu
        }
    }
    
    var body: some View {
        Group {
            switch currentScreen {
            case .menu:
                menuView()
            case .pdfViewer:
                PDFGridListView()
            case .imageConverter:
                ImageToPDFView()
            }
        }
    }
    
    private func menuView() -> some View {
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
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: DesignSystem.Colors.primaryGradientStart).opacity(Constants.leftCircleStartOpacity),
                            Color(hex: DesignSystem.Colors.primaryGradientEnd).opacity(Constants.leftCircleEndOpacity)
                        ],
                        startPoint: .center,
                        endPoint: .trailing
                    )
                )
                .frame(
                    width: Constants.leftCircleSize,
                    height: Constants.leftCircleSize
                )
                .offset(Constants.leftCircleOffset)
                .blur(radius: Constants.circleBlurRadius)
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: DesignSystem.Colors.primaryGradientMiddle).opacity(Constants.rightCircleStartOpacity),
                            Color(hex: DesignSystem.Colors.primaryGradientStart).opacity(Constants.rightCircleEndOpacity)
                        ],
                        startPoint: .center,
                        endPoint: .leading
                    )
                )
                .frame(
                    width: Constants.rightCircleSize,
                    height: Constants.rightCircleSize
                )
                .offset(Constants.rightCircleOffset)
                .blur(radius: Constants.circleBlurRadius)
            
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
                                color: Color(hex: DesignSystem.Colors.primaryGradientStart).opacity(Constants.iconShadowOpacity),
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
                    
                    VStack(spacing: Constants.titleSubtitleSpacing) {
                        Text(DesignSystem.Text.pdfHubTitle)
                            .font(
                                .system(
                                    size: Constants.titleFontSize,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundColor(Color(hex: DesignSystem.Colors.titleColor))
                        
                        Text(DesignSystem.Text.pdfHubSubtitle)
                            .font(
                                .system(
                                    size: Constants.subtitleFontSize,
                                    weight: .medium,
                                    design: .rounded
                                )
                            )
                            .foregroundColor(Color(hex: DesignSystem.Colors.subtitleColor))
                    }
                }
                .padding(.top, Constants.topPadding)
                
                HStack(spacing: Constants.buttonsHorizontalSpacing) {
                    menuButton(
                        description: Constants.pdfButtonDescription,
                        icon: DesignSystem.Icons.pdfButtonIcon,
                        fileExtensions: DesignSystem.FileTypes.pdfExtensions,
                        action: { reactor.send(.selectPDF) },
                        handleURL: { url in
                            let newPDF = PDF(pdfURL: url, rotationAngle: 0)
                            guard !selectedPDFs.contains(where: { $0.pdfURL == url }) else { return }
                            Task {
                                await MainActor.run {
                                    reactor.action(.didUserSelectPDF(selectedPDFs + [newPDF]))
                                }
                            }
                        }
                    )
                    
                    menuButton(
                        description: Constants.imageButtonDescription,
                        icon: DesignSystem.Icons.imageButtonIcon,
                        fileExtensions: DesignSystem.FileTypes.imageExtensions,
                        action: { reactor.send(.selectImages) },
                        handleURL: { url in
                            guard let image = NSImage(contentsOf: url),
                                  !reactor.state.imageURLs.contains(url)
                            else { return }
                            
                            var updatedImages = selectedImages
                            updatedImages.append(image)
                            reactor.action(.didUserSelectImages(updatedImages))
                            
                            var updatedURLs = reactor.state.imageURLs
                            updatedURLs.append(url)
                            reactor.action(.didChangeImageURLs(updatedURLs))
                        }
                    )
                }
                .padding(.bottom, Constants.bottomPadding)
            }
        }
    }

    private func menuButton(
        description: String,
        icon: String,
        fileExtensions: [String],
        action: @escaping () -> Void,
        handleURL: @escaping (URL) -> Void
    ) -> some View {
        GridMenuButtonView(
            description: description,
            icon: icon,
            action: action
        )
        .onDrop(of: [DesignSystem.FileTypes.fileURLType], isTargeted: nil) { providers in
            handleFileDrop(
                providers: providers,
                acceptedFileExtensions: fileExtensions,
                fileTypeHandler: handleURL
            )
        }
    }
    
    func handleFileDrop(
        providers: [NSItemProvider],
        acceptedFileExtensions: [String],
        fileTypeHandler: @escaping (URL) -> Void
    ) -> Bool {
        let acceptedProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(DesignSystem.FileTypes.fileURLType)
        }
        
        for provider in acceptedProviders {
            provider.loadItem(forTypeIdentifier: DesignSystem.FileTypes.fileURLType, options: nil) { item, _ in
                guard
                    let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil),
                    acceptedFileExtensions.contains(url.pathExtension.lowercased())
                else { return }
                
                Task {
                    await MainActor.run {
                        fileTypeHandler(url)
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
    
    static let pdfButtonDescription = "Split & Merge\nPDF Files"
    static let imageButtonDescription = "Convert Images\nto PDF"
}
