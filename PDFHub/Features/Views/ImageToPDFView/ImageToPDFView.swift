import SwiftUI
import AsyncReactor

struct ImageToPDFView: View {
    
    @EnvironmentObject private var reactor: PDFHubReactor
    
    @ActionBinding(
        PDFHubReactor.self,
        keyPath: \.selectedImages,
        action: PDFHubReactor.SyncAction.didUserSelectImages
    )
    private var selectedImages: [NSImage]
    
    @ActionBinding(
        PDFHubReactor.self,
        keyPath: \.imageURLs,
        action: PDFHubReactor.SyncAction.didChangeImageURLs
    )
    private var imageURLs: [URL]
    
    @ActionBinding(
        PDFHubReactor.self,
        keyPath: \.isExportAlertPresented,
        action: PDFHubReactor.SyncAction.didExportAlertPresent
    )
    private var isExportAlertPresented: Bool
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertSuccess = false
    
    let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 400), spacing: 20)
    ]
    
    var body: some View {
        content()
            .toolbar {
                
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        reactor.send(.selectImages)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add PDF")
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if !imageURLs.isEmpty {
                            reactor.send(.convertImagesToPDF(imageURLs))
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(selectedImages.isEmpty)
                    .help("Export to PDF")
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        selectedImages.removeAll()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .help("Delete All")
                }
                
            }
            .onReceive(reactor.$state) { state in
                if state.isExportAlertPresented {
                    showingAlert = true
                    alertMessage = state.exportMessage
                    alertSuccess = state.exportSuccess

                    Task {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        reactor.send(.dismissAlert)
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text(alertSuccess ? "Success" : "Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
    
    func content() -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(0..<selectedImages.count, id: \.self) { idx in
                    let image = selectedImages[idx]
                    VStack {
                        
                        HStack {
                            Spacer()
                            
                            Button {
                                reactor.send(.deleteImage(idx))
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .help("Delete This PDF")
                            
                        }
                        .font(.largeTitle)
                        .padding()
                        
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 400, maxHeight: 400)
                            .padding()
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                .mainPrimary,
                                style: StrokeStyle(
                                    lineWidth: 2,
                                    dash: [10]
                                )
                            )
                    )
                }
                
            }
        }
        .padding()
    }
}

