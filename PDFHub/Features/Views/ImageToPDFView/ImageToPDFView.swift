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
        if !selectedImages.isEmpty {
            VStack(spacing: DesignSystem.Spacing.headerSpacing) {
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
                                                Color(hex: DesignSystem.Colors.primaryGradientStart),
                                                Color(hex: DesignSystem.Colors.primaryGradientEnd)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(
                                        width: Constants.headerIconSize,
                                        height: Constants.headerIconSize
                                    )
                                
                                Image(systemName: DesignSystem.Icons.headerIcon)
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
                                Text(DesignSystem.Text.imagesToPDFTitle)
                                    .font(
                                        .system(
                                            size: DesignSystem.Typography.titleFontSize,
                                            weight: .bold,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundColor(Color(hex: DesignSystem.Colors.titleColor))
                                
                                Text("\(selectedImages.count) image\(selectedImages.count == 1 ? "" : "s") ready to convert")
                                    .font(
                                        .system(
                                            size: DesignSystem.Typography.subtitleFontSize,
                                            weight: .medium,
                                            design: .rounded
                                        )
                                    )
                                    .foregroundColor(Color(hex: DesignSystem.Colors.subtitleColor))
                            }
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: DesignSystem.Spacing.buttonSpacing) {
                        actionButton(
                            icon: DesignSystem.Icons.addButtonIcon,
                            title: DesignSystem.ButtonLabels.addImages,
                            color: Color(hex: DesignSystem.Colors.addButtonColor)
                        ) {
                            reactor.send(.selectImages)
                        }
                        
                        actionButton(
                            icon: DesignSystem.Icons.convertButtonIcon,
                            title: DesignSystem.ButtonLabels.convertToPDF,
                            color: Color(hex: DesignSystem.Colors.convertButtonColor),
                            isDisabled: selectedImages.isEmpty
                        ) {
                            if !imageURLs.isEmpty {
                                reactor.send(.convertImagesToPDF(imageURLs))
                            }
                        }
                        
                        actionButton(
                            icon: DesignSystem.Icons.clearButtonIcon,
                            title: DesignSystem.ButtonLabels.clearAll,
                            color: Color(hex: DesignSystem.Colors.clearButtonColor)
                        ) {
                            reactor.send(.clearImages)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.headerHorizontalPadding)
                .padding(.top, DesignSystem.Spacing.headerTopPadding)
                
                HStack {
                    ForEach(0..<min(selectedImages.count, Constants.maxVisibleDots), id: \.self) { index in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: DesignSystem.Colors.primaryGradientStart),
                                        Color(hex: DesignSystem.Colors.primaryGradientEnd)
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
                            .font(.system(size: DesignSystem.Typography.counterFontSize, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: DesignSystem.Colors.subtitleColor))
                    }
                }
                .padding(
                    .horizontal,
                    DesignSystem.Spacing.headerHorizontalPadding
                )
                
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
                    .padding(
                        .horizontal,
                        DesignSystem.Spacing.headerHorizontalPadding
                    )
            }
            .padding(
                .bottom,
                DesignSystem.Spacing.headerBottomPadding
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
                            size: DesignSystem.Typography.buttonFontSize,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
            }
            .foregroundColor(isDisabled ? .gray : .white)
            .padding(.horizontal, DesignSystem.Spacing.buttonHorizontalPadding)
            .padding(.vertical, DesignSystem.Spacing.buttonVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                    .fill(isDisabled ? Color.gray.opacity(0.3) : color)
                    .shadow(
                        color: isDisabled ? .clear : color.opacity(DesignSystem.Shadows.defaultOpacity),
                        radius: DesignSystem.Shadows.defaultRadius,
                        x: DesignSystem.Shadows.defaultOffset.width,
                        y: DesignSystem.Shadows.defaultOffset.height
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
                                Image(systemName: DesignSystem.Icons.deleteIconFill)
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
                            .help("Delete This Image")
                        }
                        .padding(DesignSystem.Spacing.contentPadding)
                        
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                maxWidth: Constants.imageMaxWidth,
                                maxHeight: Constants.imageMaxHeight
                            )
                            .padding(DesignSystem.Spacing.contentPadding)
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
                                    Color(hex: DesignSystem.Colors.primaryGradientStart).opacity(DesignSystem.Opacity.cardBorderStart),
                                    Color(hex: DesignSystem.Colors.primaryGradientEnd).opacity(DesignSystem.Opacity.cardBorderEnd)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: Constants.cardBorderWidth
                        )
                    )
                }
            }
            .padding(DesignSystem.Spacing.contentPadding)
        }
    }
}

private enum Constants {
    static let circleSize: CGFloat = 350
    static let circleOffset = CGSize(width: 300, height: -150)
    static let circleBlurRadius: CGFloat = 2
    
    static let headerIconSize: CGFloat = 40
    static let headerIconImageSize: CGFloat = 18
    static let headerHorizontalSpacing: CGFloat = 12
    static let headerVerticalSpacing: CGFloat = 4
    static let headerTextSpacing: CGFloat = 2
    
    static let separatorHeight: CGFloat = 2
    
    static let buttonIconSize: CGFloat = 16
    
    static let dotSize: CGFloat = 8
    static let maxVisibleDots = 10
    static let activeDotScale: CGFloat = 1.0
    static let inactiveDotScale: CGFloat = 0.5
    static let activeDotOpacity: Double = 1.0
    static let inactiveDotOpacity: Double = 0.3
    
    static let gridSpacing: CGFloat = 20
    static let imageMaxWidth: CGFloat = 400
    static let imageMaxHeight: CGFloat = 400
    static let cardCornerRadius: CGFloat = 12
    static let cardBorderWidth: CGFloat = 1
    static let cardShadowOpacity: Double = 0.08
    static let cardShadowRadius: CGFloat = 12
    static let cardShadowOffset: CGFloat = 4
    
    static let deleteButtonIconSize: CGFloat = 16
    static let deleteButtonSize: CGFloat = 32
    static let deleteButtonShadowOpacity: Double = 0.3
    static let deleteButtonShadowRadius: CGFloat = 6
    static let deleteButtonShadowOffset: CGFloat = 3
}
