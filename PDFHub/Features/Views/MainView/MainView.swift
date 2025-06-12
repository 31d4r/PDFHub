import SwiftUI
import PDFKit
import AsyncReactor

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
    
    @ViewBuilder
    private func menuView() -> some View {
        VStack {
            Image(.pdfHubCover)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 700)
            
            HStack {
                Spacer()
                menuButton(
                    description: "Choose PDF files or drop here",
                    icon: "doc",
                    fileExtensions: ["pdf"],
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
                Spacer()
                menuButton(
                    description: "Choose image files or drop files here",
                    icon: "photo.stack",
                    fileExtensions: ["png", "jpg", "jpeg", "tiff", "heic", "bmp", "gif"],
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
                Spacer()
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
        GridMenuButtonView(description: description, icon: icon, action: action)
            .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                handleFileDrop(providers: providers, acceptedFileExtensions: fileExtensions, fileTypeHandler: handleURL)
            }
    }
    
    func handleFileDrop(
        providers: [NSItemProvider],
        acceptedFileExtensions: [String],
        fileTypeHandler: @escaping (URL) -> Void
    ) -> Bool {
        let acceptedProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier("public.file-url")
        }
        
        for provider in acceptedProviders {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
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
