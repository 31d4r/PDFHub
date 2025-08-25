import AsyncReactor
import SwiftUI

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
        GridItem(
            .adaptive(minimum: 200, maximum: 400),
            spacing: 20
        )
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
        if !selectedImages.isEmpty {
            VStack(spacing: Constants.headerSpacing) {
                HStack {
                    VStack(
                        alignment: .leading,
                        spacing: Constants.headerVerticalSpacing
                    ) {
                        HStack(spacing: Constants.headerHorizontalSpacing) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: Constants.primaryGradientStart),
                                                Color(hex: Constants.primaryGradientEnd)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(
                                        width: Constants.headerIconSize,
                                        height: Constants.headerIconSize
                                    )
                                
                                Image(systemName: Constants.headerIcon)
                                    .font(
                                        .system(
                                            size: Constants.headerIconImageSize,
                                            weight: .semibold
                                        )
                                    )
                                    .foregroundColor(.white)
                            }
                            
                            VStack(
                                alignment: .leading,
                                spacing: Constants.headerTextSpacing
                            ) {
                                Text(Constants.titleText)
                                    .font(
                                        .system(
                                            size: Constants.titleFontSize,
                                            weight: .bold,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundColor(Color(hex: Constants.titleColor))
                                
                                Text("\(selectedImages.count) image\(selectedImages.count == 1 ? "" : "s") ready to convert")
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
                    }
                    
                    Spacer()
                    
                    HStack(spacing: Constants.buttonSpacing) {
                        actionButton(
                            icon: Constants.addButtonIcon,
                            title: Constants.addButtonTitle,
                            color: Color(hex: Constants.addButtonColor)
                        ) {
                            reactor.send(.selectImages)
                        }
                        
                        actionButton(
                            icon: Constants.convertButtonIcon,
                            title: Constants.convertButtonTitle,
                            color: Color(hex: Constants.convertButtonColor),
                            isDisabled: selectedImages.isEmpty
                        ) {
                            if !imageURLs.isEmpty {
                                reactor.send(.convertImagesToPDF(imageURLs))
                            }
                        }
                        
                        actionButton(
                            icon: Constants.clearButtonIcon,
                            title: Constants.clearButtonTitle,
                            color: Color(hex: Constants.clearButtonColor)
                        ) {
                            selectedImages.removeAll()
                        }
                    }
                }
                .padding(.horizontal, Constants.headerHorizontalPadding)
                .padding(.top, Constants.headerTopPadding)
                
                HStack {
                    ForEach(0..<min(selectedImages.count, Constants.maxVisibleDots), id: \.self) { index in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: Constants.primaryGradientStart),
                                        Color(hex: Constants.primaryGradientEnd)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(
                                width: Constants.dotSize,
                                height: Constants.dotSize
                            )
                            .scaleEffect(index < selectedImages.count ? Constants.activeDotScale : Constants.inactiveDotScale)
                            .opacity(index < selectedImages.count ? Constants.activeDotOpacity : Constants.inactiveDotOpacity)
                    }
                    
                    if selectedImages.count > Constants.maxVisibleDots {
                        Text("+\(selectedImages.count - Constants.maxVisibleDots)")
                            .font(.system(size: Constants.counterFontSize, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: Constants.subtitleColor))
                    }
                }
                .padding(
                    .horizontal,
                    Constants.headerHorizontalPadding
                )
                
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
                    .padding(
                        .horizontal,
                        Constants.headerHorizontalPadding
                    )
            }
            .padding(
                .bottom,
                Constants.headerBottomPadding
            )
        }
    }
    
    private func actionButton(
        icon: String,
        title: String,
        color: Color,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(
                        .system(
                            size: Constants.buttonIconSize,
                            weight: .semibold
                        )
                    )
                
                Text(title)
                    .font(
                        .system(
                            size: Constants.buttonFontSize,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
            }
            .foregroundColor(isDisabled ? .gray : .white)
            .padding(.horizontal, Constants.buttonHorizontalPadding)
            .padding(.vertical, Constants.buttonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: Constants.buttonCornerRadius, style: .continuous)
                    .fill(isDisabled ? Color.gray.opacity(0.3) : color)
                    .shadow(
                        color: isDisabled ? .clear : color.opacity(Constants.buttonShadowOpacity),
                        radius: Constants.buttonShadowRadius,
                        x: Constants.buttonShadowOffset.width,
                        y: Constants.buttonShadowOffset.height
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
    
    func content() -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Constants.gridSpacing) {
                ForEach(0..<selectedImages.count, id: \.self) { idx in
                    let image = selectedImages[idx]
                    VStack {
                        HStack {
                            Spacer()
                            
                            Button {
                                reactor.send(.deleteImage(idx))
                            } label: {
                                Image(systemName: Constants.deleteIcon)
                                    .font(
                                        .system(
                                            size: Constants.deleteButtonIconSize,
                                            weight: .semibold
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .frame(
                                        width: Constants.deleteButtonSize,
                                        height: Constants.deleteButtonSize
                                    )
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
                            .help("Delete This Image")
                        }
                        .padding(Constants.contentPadding)
                        
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                maxWidth: Constants.imageMaxWidth,
                                maxHeight: Constants.imageMaxHeight
                            )
                            .padding(Constants.contentPadding)
                    }
                    .background(
                        RoundedRectangle(
                            cornerRadius: Constants.cardCornerRadius,
                            style: .continuous
                        )
                        .fill(.white)
                        .shadow(
                            color: .black.opacity(Constants.cardShadowOpacity),
                            radius: Constants.cardShadowRadius,
                            x: 0,
                            y: Constants.cardShadowOffset
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: Constants.cardCornerRadius,
                            style: .continuous
                        )
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: Constants.primaryGradientStart).opacity(Constants.cardBorderStartOpacity),
                                    Color(hex: Constants.primaryGradientEnd).opacity(Constants.cardBorderEndOpacity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: Constants.cardBorderWidth
                        )
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
    static let primaryGradientStart = "F7931E"
    static let primaryGradientEnd = "FFD23F"
    static let titleColor = "2D3748"
    static let subtitleColor = "4A5568"
    static let addButtonColor = "4299E1"
    static let convertButtonColor = "48BB78"
    static let clearButtonColor = "F56565"
    
    /// Background Circle
    static let circleSize: CGFloat = 350
    static let circleOffset = CGSize(width: 300, height: -150)
    static let circleStartOpacity: Double = 0.05
    static let circleEndOpacity: Double = 0.02
    static let circleBlurRadius: CGFloat = 2
    
    /// Header Icon
    static let headerIconSize: CGFloat = 40
    static let headerIconImageSize: CGFloat = 18
    static let headerSpacing: CGFloat = 16
    static let headerHorizontalSpacing: CGFloat = 12
    static let headerVerticalSpacing: CGFloat = 4
    static let headerTextSpacing: CGFloat = 2
    
    /// Typography
    static let titleFontSize: CGFloat = 28
    static let subtitleFontSize: CGFloat = 16
    static let counterFontSize: CGFloat = 12
    
    /// Header Layout
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
    
    /// Progress Dots
    static let dotSize: CGFloat = 8
    static let maxVisibleDots = 10
    static let activeDotScale: CGFloat = 1.0
    static let inactiveDotScale: CGFloat = 0.5
    static let activeDotOpacity: Double = 1.0
    static let inactiveDotOpacity: Double = 0.3
    
    /// Content Layout
    static let gridSpacing: CGFloat = 20
    static let imageMaxWidth: CGFloat = 400
    static let imageMaxHeight: CGFloat = 400
    static let contentPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 12
    static let cardBorderWidth: CGFloat = 1
    static let cardShadowOpacity: Double = 0.08
    static let cardShadowRadius: CGFloat = 12
    static let cardShadowOffset: CGFloat = 4
    static let cardBorderStartOpacity: Double = 0.2
    static let cardBorderEndOpacity: Double = 0.1
    
    /// Delete Button
    static let deleteIcon = "trash.fill"
    static let deleteButtonIconSize: CGFloat = 16
    static let deleteButtonSize: CGFloat = 32
    static let deleteButtonBackgroundColor = "F56565"
    static let deleteButtonShadowOpacity: Double = 0.3
    static let deleteButtonShadowRadius: CGFloat = 6
    static let deleteButtonShadowOffset: CGFloat = 3
    
    /// Button Labels
    static let addButtonIcon = "plus.circle.fill"
    static let addButtonTitle = "Add Images"
    static let convertButtonIcon = "arrow.down.doc.fill"
    static let convertButtonTitle = "Convert to PDF"
    static let clearButtonIcon = "trash.fill"
    static let clearButtonTitle = "Clear All"
    static let headerIcon = "photo.stack.fill"
    static let titleText = "Images to PDF"
}
