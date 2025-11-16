import SwiftUI

enum DesignSystem {
    enum Colors {
        static let backgroundGradientStart = "F7FAFC"
        static let backgroundGradientEnd = "EDF2F7"
        static let primaryGradientStart = "FF6B35"
        static let primaryGradientMiddle = "F7931E"
        static let primaryGradientEnd = "FFD23F"
        static let titleColor = "2D3748"
        static let subtitleColor = "4A5568"
        
        static let addButtonColor = "4299E1"
        static let splitButtonColor = "48BB78"
        static let mergeButtonColor = "F7931E"
        static let convertButtonColor = "48BB78"
        static let deleteButtonColor = "F56565"
        static let rotateButtonColor = "4299E1"
        static let clearButtonColor = "F56565"
        
        static let pdfContainerBackgroundColor = "F7FAFC"
        static let deleteButtonBackgroundColor = "F56565"
    }
    
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 32
        static let extraLarge: CGFloat = 40
        
        static let buttonSpacing: CGFloat = 12
        static let buttonHorizontalPadding: CGFloat = 16
        static let buttonVerticalPadding: CGFloat = 10
        static let contentPadding: CGFloat = 16
        static let headerHorizontalPadding: CGFloat = 32
        static let headerTopPadding: CGFloat = 20
        static let headerBottomPadding: CGFloat = 20
        static let headerSpacing: CGFloat = 16
    }
    
    enum Typography {
        static let titleFontSize: CGFloat = 28
        static let subtitleFontSize: CGFloat = 16
        static let buttonFontSize: CGFloat = 14
        static let fileNameFontSize: CGFloat = 16
        static let documentTypeFontSize: CGFloat = 12
        static let counterFontSize: CGFloat = 12
    }
    
    enum Shadows {
        static let defaultOpacity: Double = 0.3
        static let backgroundOpacity: Double = 0.08
        static let defaultRadius: CGFloat = 8
        static let backgroundRadius: CGFloat = 12
        static let defaultOffset = CGSize(width: 0, height: 4)
        static let backgroundOffset: CGFloat = 4
    }
    
    enum CornerRadius {
        static let button: CGFloat = 12
        static let card: CGFloat = 20
        static let cardSmall: CGFloat = 12
        static let pdfContainer: CGFloat = 16
        static let pdfView: CGFloat = 12
    }
    
    enum Opacity {
        static let circleStart: Double = 0.05
        static let circleEnd: Double = 0.02
        static let separatorStart: Double = 0.3
        static let separatorEnd: Double = 0.1
        static let cardBorderStart: Double = 0.2
        static let cardBorderEnd: Double = 0.1
    }
    
    enum Icons {
        static let addButtonIcon = "plus.circle.fill"
        static let splitButtonIcon = "rectangle.split.2x1.fill"
        static let mergeButtonIcon = "arrow.triangle.merge"
        static let convertButtonIcon = "arrow.down.doc.fill"
        static let clearButtonIcon = "trash.fill"
        static let deleteIconFill = "trash.fill"
        static let rotateLeftIconFill = "rotate.left.fill"
        static let rotateRightIconFill = "rotate.right.fill"
        static let pdfButtonIcon = "doc.text.fill"
        static let imageButtonIcon = "photo.stack.fill"
        static let headerIcon = "photo.stack.fill"
    }
    
    enum ButtonLabels {
        static let addPDF = "Add PDF"
        static let addImages = "Add Images"
        static let splitPDFs = "Split PDFs"
        static let mergePDFs = "Merge PDFs"
        static let convertToPDF = "Convert to PDF"
        static let clearAll = "Clear All"
    }
    
    enum Text {
        static let pdfDocument = "PDF Document"
        static let pdfHubTitle = "PDF HUB"
        static let pdfHubSubtitle = "Your PDF workflow companion"
        static let pdfDocumentsTitle = "PDF Documents"
        static let imagesToPDFTitle = "Images to PDF"
    }
    
    enum FileTypes {
        static let pdfExtensions = ["pdf"]
        static let imageExtensions = ["png", "jpg", "jpeg", "tiff", "heic", "bmp", "gif"]
        static let fileURLType = "public.file-url"
    }
}

