import AsyncReactor
import PDFKit
import SwiftUI

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
                            Color(hex: Constants.primaryGradientStart).opacity(Constants.circleStartOpacity),
                            Color(hex: Constants.primaryGradientEnd).opacity(Constants.circleEndOpacity)
                        ],
                        startPoint: .center,
                        endPoint: .trailing
                    )
                )
                .frame(
                    width: Constants.circleSize,
                    height: Constants.circleSize
                )
                .offset(Constants.circleOffset)
                .blur(radius: Constants.circleBlurRadius)
            
            VStack(spacing: 0) {
                headerView()
                content()
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
    
    @ViewBuilder
    private func headerView() -> some View {
        if !selectedPDFs.isEmpty {
            VStack(spacing: Constants.headerSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Constants.titleText)
                            .font(
                                .system(size: Constants.titleFontSize, weight: .bold, design: .rounded)
                            )
                            .foregroundColor(Color(hex: Constants.titleColor))
                        
                        Text("\(selectedPDFs.count) file\(selectedPDFs.count == 1 ? "" : "s") loaded")
                            .font(.system(size: Constants.subtitleFontSize, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: Constants.subtitleColor))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: Constants.buttonSpacing) {
                        actionButton(
                            icon: Constants.addButtonIcon,
                            title: Constants.addButtonTitle,
                            color: Color(hex: Constants.addButtonColor)
                        ) {
                            reactor.send(.selectPDF)
                        }
                        
                        actionButton(
                            icon: Constants.splitButtonIcon,
                            title: Constants.splitButtonTitle,
                            color: Color(hex: Constants.splitButtonColor)
                        ) {
                            let urls = selectedPDFs.map { $0.pdfURL }
                            reactor.send(.splitPDF(urls))
                        }
                        
                        actionButton(
                            icon: Constants.mergeButtonIcon,
                            title: Constants.mergeButtonTitle,
                            color: Color(hex: Constants.mergeButtonColor)
                        ) {
                            let urls = selectedPDFs.map { $0.pdfURL }
                            reactor.send(.mergePDF(urls))
                        }
                        
                        actionButton(
                            icon: Constants.clearButtonIcon,
                            title: Constants.clearButtonTitle,
                            color: Color(hex: Constants.deleteButtonColor)
                        ) {
                            selectedPDFs.removeAll()
                        }
                    }
                }
                .padding(.horizontal, Constants.headerHorizontalPadding)
                .padding(.top, Constants.headerTopPadding)
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: Constants.primaryGradientStart).opacity(Constants.separatorStartOpacity),
                                Color(hex: Constants.primaryGradientEnd).opacity(Constants.separatorEndOpacity)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: Constants.separatorHeight)
                    .padding(.horizontal, Constants.headerHorizontalPadding)
            }
            .padding(.bottom, Constants.headerBottomPadding)
        }
    }
    
    private func actionButton(
        icon: String,
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: Constants.buttonIconSize, weight: .semibold))
                
                Text(title)
                    .font(.system(size: Constants.buttonFontSize, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, Constants.buttonHorizontalPadding)
            .padding(.vertical, Constants.buttonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: Constants.buttonCornerRadius, style: .continuous)
                    .fill(color)
                    .shadow(
                        color: color.opacity(Constants.buttonShadowOpacity),
                        radius: Constants.buttonShadowRadius,
                        x: Constants.buttonShadowOffset.width,
                        y: Constants.buttonShadowOffset.height
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    func content() -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Constants.gridSpacing) {
                ForEach($selectedPDFs) { $pdf in
                    VStack(spacing: 0) {
                        HStack {
                            HStack(spacing: Constants.rotateButtonSpacing) {
                                Button {
                                    withAnimation(.easeInOut(duration: Constants.rotateAnimationDuration)) {
                                        pdf.rotationAngle = (pdf.rotationAngle - 90 + 360) % 360
                                    }
                                } label: {
                                    Image(systemName: Constants.rotateLeftIconFill)
                                        .font(.system(size: Constants.rotateIconSize, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: Constants.rotateButtonSize, height: Constants.rotateButtonSize)
                                        .background(
                                            Circle()
                                                .fill(Color(hex: Constants.rotateButtonColor))
                                                .shadow(
                                                    color: Color(hex: Constants.rotateButtonColor).opacity(Constants.rotateButtonShadowOpacity),
                                                    radius: Constants.rotateButtonShadowRadius,
                                                    x: 0,
                                                    y: Constants.rotateButtonShadowOffset
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    withAnimation(.easeInOut(duration: Constants.rotateAnimationDuration)) {
                                        pdf.rotationAngle = (pdf.rotationAngle + 90) % 360
                                    }
                                } label: {
                                    Image(systemName: Constants.rotateRightIconFill)
                                        .font(.system(size: Constants.rotateIconSize, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: Constants.rotateButtonSize, height: Constants.rotateButtonSize)
                                        .background(
                                            Circle()
                                                .fill(Color(hex: Constants.rotateButtonColor))
                                                .shadow(
                                                    color: Color(hex: Constants.rotateButtonColor).opacity(Constants.rotateButtonShadowOpacity),
                                                    radius: Constants.rotateButtonShadowRadius,
                                                    x: 0,
                                                    y: Constants.rotateButtonShadowOffset
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                            
                            Button {
                                reactor.send(.deletePDF($pdf.id))
                            } label: {
                                Image(systemName: Constants.deleteIconFill)
                                    .font(.system(size: Constants.deleteIconSize, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: Constants.deleteButtonSize, height: Constants.deleteButtonSize)
                                    .background(
                                        Circle()
                                            .fill(Color(hex: Constants.deleteButtonBackgroundColor))
                                            .shadow(
                                                color: Color(hex: Constants.deleteButtonBackgroundColor).opacity(Constants.deleteButtonShadowOpacity),
                                                radius: Constants.deleteButtonShadowRadius,
                                                x: 0,
                                                y: Constants.deleteButtonShadowOffset
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Constants.cardHorizontalPadding)
                        .padding(.top, Constants.cardTopPadding)
                        .padding(.bottom, Constants.cardMiddlePadding)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: Constants.pdfContainerCornerRadius, style: .continuous)
                                .fill(Color(hex: Constants.pdfContainerBackgroundColor))
                                .frame(height: Constants.pdfContainerHeight)
                            
                            PDFKitView(
                                url: pdf.pdfURL,
                                rotationAngle: $pdf.rotationAngle
                            )
                            .frame(height: Constants.pdfViewHeight)
                            .clipShape(RoundedRectangle(cornerRadius: Constants.pdfViewCornerRadius, style: .continuous))
                            .shadow(
                                color: .black.opacity(Constants.pdfViewShadowOpacity),
                                radius: Constants.pdfViewShadowRadius,
                                x: 0,
                                y: Constants.pdfViewShadowOffset
                            )
                        }
                        .padding(.horizontal, Constants.cardHorizontalPadding)
                        
                        VStack(spacing: Constants.textSpacing) {
                            Text(pdf.pdfURL.lastPathComponent)
                                .font(.system(size: Constants.fileNameFontSize, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: Constants.titleColor))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            
                            Text(Constants.pdfDocumentText)
                                .font(.system(size: Constants.documentTypeFontSize, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: Constants.subtitleColor))
                        }
                        .padding(.horizontal, Constants.cardHorizontalPadding)
                        .padding(.vertical, Constants.cardBottomPadding)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Constants.cardCornerRadius, style: .continuous)
                            .fill(.white)
                    )
                }
            }
            .padding(Constants.contentPadding)
        }
    }
}

private enum Constants {
    /// Colors
    static let backgroundGradientStart = "F7FAFC"
    static let backgroundGradientEnd = "EDF2F7"
    static let primaryGradientStart = "FF6B35"
    static let primaryGradientEnd = "FFD23F"
    static let titleColor = "2D3748"
    static let subtitleColor = "4A5568"
    static let addButtonColor = "4299E1"
    static let splitButtonColor = "48BB78"
    static let mergeButtonColor = "F7931E"
    static let deleteButtonColor = "F56565"
    
    /// Background Circle
    static let circleSize: CGFloat = 400
    static let circleOffset = CGSize(width: -250, height: -200)
    static let circleStartOpacity: Double = 0.05
    static let circleEndOpacity: Double = 0.02
    static let circleBlurRadius: CGFloat = 2
    
    /// Header
    static let headerSpacing: CGFloat = 16
    static let titleFontSize: CGFloat = 28
    static let subtitleFontSize: CGFloat = 16
    static let headerHorizontalPadding: CGFloat = 32
    static let headerTopPadding: CGFloat = 20
    static let headerBottomPadding: CGFloat = 20
    static let separatorHeight: CGFloat = 2
    static let separatorStartOpacity: Double = 0.3
    static let separatorEndOpacity: Double = 0.1
    
    /// Action Buttons
    static let buttonSpacing: CGFloat = 12
    static let buttonIconSize: CGFloat = 16
    static let buttonFontSize: CGFloat = 14
    static let buttonHorizontalPadding: CGFloat = 16
    static let buttonVerticalPadding: CGFloat = 10
    static let buttonCornerRadius: CGFloat = 12
    static let buttonShadowOpacity: Double = 0.3
    static let buttonShadowRadius: CGFloat = 8
    static let buttonShadowOffset = CGSize(width: 0, height: 4)
    
    /// Content Layout
    static let gridSpacing: CGFloat = 20
    static let contentPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 20
    static let cardHorizontalPadding: CGFloat = 20
    static let cardTopPadding: CGFloat = 20
    static let cardMiddlePadding: CGFloat = 16
    static let cardBottomPadding: CGFloat = 16
    static let cardShadowOpacity: Double = 0.08
    static let cardShadowRadius: CGFloat = 12
    static let cardShadowOffset: CGFloat = 4
    static let cardHoverShadowOpacity: Double = 0.15
    static let cardHoverShadowRadius: CGFloat = 20
    static let cardHoverShadowOffset: CGFloat = 8
    static let cardBorderWidth: CGFloat = 1
    static let cardHoverBorderWidth: CGFloat = 2
    static let cardBorderStartOpacity: Double = 0.2
    static let cardBorderEndOpacity: Double = 0.1
    static let cardHoverBorderStartOpacity: Double = 0.4
    static let cardHoverBorderEndOpacity: Double = 0.2
    static let cardNormalScale: CGFloat = 1.0
    static let cardHoverScale: CGFloat = 1.02
    static let cardAnimationDuration: Double = 0.2
    
    /// PDF Container
    static let pdfContainerHeight: CGFloat = 400
    static let pdfContainerCornerRadius: CGFloat = 16
    static let pdfContainerBackgroundColor = "F7FAFC"
    static let pdfViewHeight: CGFloat = 380
    static let pdfViewCornerRadius: CGFloat = 12
    static let pdfViewShadowOpacity: Double = 0.1
    static let pdfViewShadowRadius: CGFloat = 8
    static let pdfViewShadowOffset: CGFloat = 4
    
    /// Rotation Buttons
    static let rotateButtonSpacing: CGFloat = 8
    static let rotateButtonSize: CGFloat = 32
    static let rotateIconSize: CGFloat = 14
    static let rotateButtonColor = "4299E1"
    static let rotateButtonShadowOpacity: Double = 0.3
    static let rotateButtonShadowRadius: CGFloat = 6
    static let rotateButtonShadowOffset: CGFloat = 3
    static let rotateAnimationDuration: Double = 0.3
    
    /// Delete Button
    static let deleteButtonSize: CGFloat = 32
    static let deleteIconSize: CGFloat = 16
    static let deleteButtonBackgroundColor = "F56565"
    static let deleteButtonShadowOpacity: Double = 0.3
    static let deleteButtonShadowRadius: CGFloat = 6
    static let deleteButtonShadowOffset: CGFloat = 3
    
    /// Text
    static let textSpacing: CGFloat = 8
    static let fileNameFontSize: CGFloat = 16
    static let documentTypeFontSize: CGFloat = 12
    static let pdfDocumentText = "PDF Document"
    
    /// Icons
    static let rotateLeftIconFill = "rotate.left.fill"
    static let rotateRightIconFill = "rotate.right.fill"
    static let deleteIconFill = "trash.fill"
    
    /// Button Labels
    static let addButtonIcon = "plus.circle.fill"
    static let addButtonTitle = "Add PDF"
    static let splitButtonIcon = "rectangle.split.2x1.fill"
    static let splitButtonTitle = "Split PDFs"
    static let mergeButtonIcon = "arrow.triangle.merge"
    static let mergeButtonTitle = "Merge PDFs"
    static let clearButtonIcon = "trash.fill"
    static let clearButtonTitle = "Clear All"
    static let titleText = "PDF Documents"
}
