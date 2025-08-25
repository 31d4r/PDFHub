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
                    Color(hex: Constants.backgroundGradientStart),
                    Color(hex: Constants.backgroundGradientEnd)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: Constants.primaryGradientStart).opacity(Constants.leftCircleStartOpacity),
                            Color(hex: Constants.primaryGradientEnd).opacity(Constants.leftCircleEndOpacity)
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
                            Color(hex: Constants.primaryGradientMiddle).opacity(Constants.rightCircleStartOpacity),
                            Color(hex: Constants.primaryGradientStart).opacity(Constants.rightCircleEndOpacity)
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
                                        Color(hex: Constants.primaryGradientStart),
                                        Color(hex: Constants.primaryGradientMiddle),
                                        Color(hex: Constants.primaryGradientEnd)
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
                                color: Color(hex: Constants.primaryGradientStart).opacity(Constants.iconShadowOpacity),
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
                        Text(Constants.titleText)
                            .font(
                                .system(
                                    size: Constants.titleFontSize,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundColor(Color(hex: Constants.titleColor))
                        
                        Text(Constants.subtitleText)
                            .font(
                                .system(
                                    size: Constants.subtitleFontSize,
                                    weight: .medium,
                                    design: .rounded
                                )
                            )
                            .foregroundColor(Color(hex: Constants.subtitleColor))
                    }
                }
                .padding(.top, Constants.topPadding)
                
                HStack(spacing: Constants.buttonsHorizontalSpacing) {
                    menuButton(
                        description: Constants.pdfButtonDescription,
                        icon: Constants.pdfButtonIcon,
                        fileExtensions: Constants.pdfExtensions,
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
                        icon: Constants.imageButtonIcon,
                        fileExtensions: Constants.imageExtensions,
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
        .onDrop(of: [Constants.fileURLType], isTargeted: nil) { providers in
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
            $0.hasItemConformingToTypeIdentifier(Constants.fileURLType)
        }
        
        for provider in acceptedProviders {
            provider.loadItem(forTypeIdentifier: Constants.fileURLType, options: nil) { item, _ in
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
    /// Colors
    static let backgroundGradientStart = "F7FAFC"
    static let backgroundGradientEnd = "EDF2F7"
    static let primaryGradientStart = "FF6B35"
    static let primaryGradientMiddle = "F7931E"
    static let primaryGradientEnd = "FFD23F"
    static let titleColor = "2D3748"
    static let subtitleColor = "4A5568"
    
    /// Background Circles
    static let leftCircleSize: CGFloat = 300
    static let rightCircleSize: CGFloat = 200
    static let leftCircleOffset = CGSize(width: -200, height: -150)
    static let rightCircleOffset = CGSize(width: 300, height: 200)
    static let leftCircleStartOpacity: Double = 0.1
    static let leftCircleEndOpacity: Double = 0.05
    static let rightCircleStartOpacity: Double = 0.08
    static let rightCircleEndOpacity: Double = 0.03
    static let circleBlurRadius: CGFloat = 1
    
    /// App Icon
    static let iconCircleSize: CGFloat = 120
    static let iconSize: CGFloat = 80
    static let iconShadowOpacity: Double = 0.3
    static let iconShadowRadius: CGFloat = 20
    static let iconShadowOffset = CGSize(width: 0, height: 10)
    
    /// Typography
    static let titleFontSize: CGFloat = 48
    static let subtitleFontSize: CGFloat = 18
    static let titleText = "PDF HUB"
    static let subtitleText = "Your PDF workflow companion"
    
    /// Spacing
    static let mainVerticalSpacing: CGFloat = 40
    static let titleVerticalSpacing: CGFloat = 20
    static let titleSubtitleSpacing: CGFloat = 8
    static let buttonsHorizontalSpacing: CGFloat = 40
    static let topPadding: CGFloat = 40
    static let bottomPadding: CGFloat = 60
    
    /// Menu Button Content
    static let pdfButtonDescription = "Split & Merge\nPDF Files"
    static let pdfButtonIcon = "doc.text.fill"
    static let imageButtonDescription = "Convert Images\nto PDF"
    static let imageButtonIcon = "photo.stack.fill"
    
    /// File Extensions
    static let pdfExtensions = ["pdf"]
    static let imageExtensions = ["png", "jpg", "jpeg", "tiff", "heic", "bmp", "gif"]
    
    /// Drop Handling
    static let fileURLType = "public.file-url"
}
