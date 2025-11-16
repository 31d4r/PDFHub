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
                            Color(hex: DesignSystem.Colors.primaryGradientStart).opacity(DesignSystem.Opacity.circleStart),
                            Color(hex: DesignSystem.Colors.primaryGradientEnd).opacity(DesignSystem.Opacity.circleEnd)
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
            VStack(spacing: DesignSystem.Spacing.headerSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DesignSystem.Text.pdfDocumentsTitle)
                            .font(
                                .system(size: DesignSystem.Typography.titleFontSize, weight: .bold, design: .rounded)
                            )
                            .foregroundColor(Color(hex: DesignSystem.Colors.titleColor))
                        
                        Text("\(selectedPDFs.count) file\(selectedPDFs.count == 1 ? "" : "s") loaded")
                            .font(.system(size: DesignSystem.Typography.subtitleFontSize, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: DesignSystem.Colors.subtitleColor))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: DesignSystem.Spacing.buttonSpacing) {
                        actionButton(
                            icon: DesignSystem.Icons.addButtonIcon,
                            title: DesignSystem.ButtonLabels.addPDF,
                            color: Color(hex: DesignSystem.Colors.addButtonColor)
                        ) {
                            reactor.send(.selectPDF)
                        }
                        
                        actionButton(
                            icon: DesignSystem.Icons.splitButtonIcon,
                            title: DesignSystem.ButtonLabels.splitPDFs,
                            color: Color(hex: DesignSystem.Colors.splitButtonColor)
                        ) {
                            let urls = selectedPDFs.map { $0.pdfURL }
                            reactor.send(.splitPDF(urls))
                        }
                        
                        actionButton(
                            icon: DesignSystem.Icons.mergeButtonIcon,
                            title: DesignSystem.ButtonLabels.mergePDFs,
                            color: Color(hex: DesignSystem.Colors.mergeButtonColor)
                        ) {
                            let urls = selectedPDFs.map { $0.pdfURL }
                            reactor.send(.mergePDF(urls))
                        }
                        
                        actionButton(
                            icon: DesignSystem.Icons.clearButtonIcon,
                            title: DesignSystem.ButtonLabels.clearAll,
                            color: Color(hex: DesignSystem.Colors.deleteButtonColor)
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
                                Color(hex: DesignSystem.Colors.primaryGradientStart).opacity(DesignSystem.Opacity.separatorStart),
                                Color(hex: DesignSystem.Colors.primaryGradientEnd).opacity(DesignSystem.Opacity.separatorEnd)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: Constants.separatorHeight)
                    .padding(.horizontal, DesignSystem.Spacing.headerHorizontalPadding)
            }
            .padding(.bottom, DesignSystem.Spacing.headerBottomPadding)
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
                    .font(.system(size: DesignSystem.Typography.buttonFontSize, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.buttonHorizontalPadding)
            .padding(.vertical, DesignSystem.Spacing.buttonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                    .fill(color)
                    .shadow(
                        color: color.opacity(DesignSystem.Shadows.defaultOpacity),
                        radius: DesignSystem.Shadows.defaultRadius,
                        x: DesignSystem.Shadows.defaultOffset.width,
                        y: DesignSystem.Shadows.defaultOffset.height
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
                                    Image(systemName: DesignSystem.Icons.rotateLeftIconFill)
                                        .font(.system(size: Constants.rotateIconSize, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: Constants.rotateButtonSize, height: Constants.rotateButtonSize)
                                        .background(
                                            Circle()
                                                .fill(Color(hex: DesignSystem.Colors.rotateButtonColor))
                                                .shadow(
                                                    color: Color(hex: DesignSystem.Colors.rotateButtonColor).opacity(Constants.rotateButtonShadowOpacity),
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
                                    Image(systemName: DesignSystem.Icons.rotateRightIconFill)
                                        .font(.system(size: Constants.rotateIconSize, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: Constants.rotateButtonSize, height: Constants.rotateButtonSize)
                                        .background(
                                            Circle()
                                                .fill(Color(hex: DesignSystem.Colors.rotateButtonColor))
                                                .shadow(
                                                    color: Color(hex: DesignSystem.Colors.rotateButtonColor).opacity(Constants.rotateButtonShadowOpacity),
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
                                Image(systemName: DesignSystem.Icons.deleteIconFill)
                                    .font(.system(size: Constants.deleteIconSize, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: Constants.deleteButtonSize, height: Constants.deleteButtonSize)
                                    .background(
                                        Circle()
                                            .fill(Color(hex: DesignSystem.Colors.deleteButtonBackgroundColor))
                                            .shadow(
                                                color: Color(hex: DesignSystem.Colors.deleteButtonBackgroundColor).opacity(Constants.deleteButtonShadowOpacity),
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
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.pdfContainer, style: .continuous)
                                .fill(Color(hex: DesignSystem.Colors.pdfContainerBackgroundColor))
                                .frame(height: Constants.pdfContainerHeight)
                            
                            PDFKitView(
                                url: pdf.pdfURL,
                                rotationAngle: $pdf.rotationAngle
                            )
                            .frame(height: Constants.pdfViewHeight)
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.pdfView, style: .continuous))
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
                                .font(.system(size: DesignSystem.Typography.fileNameFontSize, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: DesignSystem.Colors.titleColor))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            
                            Text(DesignSystem.Text.pdfDocument)
                                .font(.system(size: DesignSystem.Typography.documentTypeFontSize, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: DesignSystem.Colors.subtitleColor))
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
            .padding(DesignSystem.Spacing.contentPadding)
        }
    }
}

private enum Constants {
    static let circleSize: CGFloat = 400
    static let circleOffset = CGSize(width: -250, height: -200)
    static let circleBlurRadius: CGFloat = 2
    
    static let separatorHeight: CGFloat = 2
    
    static let buttonIconSize: CGFloat = 16
    
    static let gridSpacing: CGFloat = 20
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
    static let cardHoverBorderStartOpacity: Double = 0.4
    static let cardHoverBorderEndOpacity: Double = 0.2
    static let cardNormalScale: CGFloat = 1.0
    static let cardHoverScale: CGFloat = 1.02
    static let cardAnimationDuration: Double = 0.2
    
    static let pdfContainerHeight: CGFloat = 400
    static let pdfViewHeight: CGFloat = 380
    static let pdfViewShadowOpacity: Double = 0.1
    
    static let rotateButtonSpacing: CGFloat = 8
    static let rotateButtonSize: CGFloat = 32
    static let rotateIconSize: CGFloat = 14
    static let rotateButtonShadowOpacity: Double = 0.3
    static let rotateButtonShadowRadius: CGFloat = 6
    static let rotateButtonShadowOffset: CGFloat = 3
    static let rotateAnimationDuration: Double = 0.3
    
    static let deleteButtonSize: CGFloat = 32
    static let deleteIconSize: CGFloat = 16
    static let deleteButtonShadowOpacity: Double = 0.3
    static let deleteButtonShadowRadius: CGFloat = 6
    static let deleteButtonShadowOffset: CGFloat = 3
    
    static let textSpacing: CGFloat = 8
}
