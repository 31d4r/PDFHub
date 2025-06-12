import SwiftUI
import PDFKit
import AsyncReactor

struct PDFGridListView: View {
    
    @EnvironmentObject private var reactor: PDFHubReactor
    
    @ActionBinding(
        PDFHubReactor.self,
        keyPath: \.selectedPDFs,
        action: PDFHubReactor.SyncAction.didUserSelectPDF
    )
    private var selectedPDFs: [PDF]
    
    @ActionBinding(
        PDFHubReactor.self,
        keyPath: \.mergedPDF,
        action: PDFHubReactor.SyncAction.didMergePDF
    )
    private var mergedPDF: PDFDocument?
    
    @ActionBinding(
        PDFHubReactor.self,
        keyPath: \.splitPDFs,
        action: PDFHubReactor.SyncAction.didSplitPDFs
    )
    private var splitPDFs: [PDFDocument]
    
    @ActionBinding(
        PDFHubReactor.self,
        keyPath: \.isExportAlertPresented,
        action: PDFHubReactor.SyncAction.didExportAlertPresent
    )
    private var isExportAlertPresented: Bool
    
    @ActionBinding(
        PDFHubReactor.self,
        keyPath: \.rotationAngle,
        action: PDFHubReactor.SyncAction.didChangePDFRotation
    )
    private var rotationAngle: Int
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertSuccess = false
    
    let columns = [
        GridItem(.adaptive(minimum: 400))
    ]
    
    var body: some View {
        content()
            .toolbar {
                if !selectedPDFs.isEmpty {
                    
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            reactor.send(.selectPDF)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("Add PDF")
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            let urls = selectedPDFs.map { $0.pdfURL }
                            reactor.send(.splitPDF(urls))
                        } label: {
                            Image(systemName: "rectangle.split.1x2")
                        }
                        .help("Split PDF file(s) into pieces")
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            let urls = selectedPDFs.map { $0.pdfURL }
                            reactor.send(.mergePDF(urls))
                        } label: {
                            Image(systemName: "arrow.triangle.merge")
                        }
                        .help("Merge multiple PDF files into one")
                    }
                    
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            selectedPDFs.removeAll()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .help("Delete All")
                    }
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
                ForEach($selectedPDFs) { $pdf in
                    VStack {
                        
                        HStack {
                            
                            Button {
                                pdf.rotationAngle = (pdf.rotationAngle - 90 + 360) % 360
                            } label: {
                                Image(systemName: "rotate.left")
                                    .foregroundStyle(.phFontGray)
                            }
                            .help("Rotate Left")
                            
                            Button {
                                pdf.rotationAngle = (pdf.rotationAngle + 90) % 360
                            } label: {
                                Image(systemName: "rotate.right")
                                    .foregroundStyle(.phFontGray)
                            }
                            .help("Rotate Right")
                            
                            Spacer()
                            
                            Button {
                                reactor.send(.deletePDF($pdf.id))
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .help("Delete This PDF")
                            
                        }
                        .font(.largeTitle)
                        .padding()
                        
                        PDFKitView(
                            url: pdf.pdfURL,
                            rotationAngle: $pdf.rotationAngle
                        )
                        .frame(width: 400, height: 500)
                        
                        Text(pdf.pdfURL.lastPathComponent)
                            .foregroundStyle(.phFontGray)
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
            .padding()
        }
    }
}
