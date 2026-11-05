import BeaverCore
import SwiftUI

enum DesignSystem {
    /// Named colours from the asset catalog. Neutrals have Dark Mode variants;
    /// brand and action colours are the same in both appearances.
    enum Colors {
        static let backgroundGradientStart = Color(.backgroundStart)
        static let backgroundGradientEnd = Color(.backgroundEnd)
        static let primaryGradientStart = Color(.brandOrange)
        static let primaryGradientMiddle = Color(.brandAmber)
        static let primaryGradientEnd = Color(.brandYellow)
        static let titleColor = Color(.titleText)
        static let subtitleColor = Color(.subtitleText)

        static let addButtonColor = Color(.actionBlue)
        static let splitButtonColor = Color(.actionGreen)
        static let mergeButtonColor = Color(.brandAmber)
        static let convertButtonColor = Color(.actionGreen)
        static let destructiveButtonColor = Color(.destructive)
        static let rotateButtonColor = Color(.actionBlue)

        static let cardSurface = Color(.cardSurface)
        static let pdfContainerBackgroundColor = Color(.pdfContainer)
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

        static let iconButtonOpacity: Double = 0.3
        static let iconButtonRadius: CGFloat = 6
        static let iconButtonOffset: CGFloat = 3
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

    enum Layout {
        static let decorativeCircleBlurRadius: CGFloat = 2
        static let separatorHeight: CGFloat = 2
        static let buttonIconSize: CGFloat = 16
        static let deleteButtonSize: CGFloat = 32
        static let deleteIconSize: CGFloat = 16
        static let rotateButtonSize: CGFloat = 32
        static let rotateIconSize: CGFloat = 14
        static let rotateButtonSpacing: CGFloat = 8
        static let rotateAnimationDuration: Double = 0.3
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
        static let backButtonIcon = "chevron.left"
    }

    enum ButtonLabels {
        static var addPDF: String { String(localized: "Add PDF") }
        static var addImages: String { String(localized: "Add Images") }
        static var splitPDFs: String { String(localized: "Split PDFs") }
        static var mergePDFs: String { String(localized: "Merge PDFs") }
        static var convertToPDF: String { String(localized: "Convert to PDF") }
        static var clearAll: String { String(localized: "Clear All") }
        static var back: String { String(localized: "Back") }
    }

    enum Text {
        static var pdfDocument: String { String(localized: "PDF Document") }
        static var beaverTitle: String { String(localized: "Beaver") }
        static var beaverSubtitle: String { String(localized: "Your PDF workflow companion") }
        static var pdfDocumentsTitle: String { String(localized: "PDF Documents") }
        static var imagesToPDFTitle: String { String(localized: "Images to PDF") }
        static var pdfButtonDescription: String { String(localized: "Split & Merge\nPDF Files") }
        static var imageButtonDescription: String { String(localized: "Convert Images\nto PDF") }

        static func pdfFilesLoadedCount(_ count: Int) -> String {
            String(localized: "\(count) files loaded")
        }

        static func imagesReadyCount(_ count: Int) -> String {
            String(localized: "\(count) images ready to convert")
        }
    }

    enum Accessibility {
        static var rotateLeft: String { String(localized: "Rotate left") }
        static var rotateRight: String { String(localized: "Rotate right") }
        static var remove: String { String(localized: "Remove") }
        static var deleteImageHelp: String { String(localized: "Delete This Image") }

        static func delete(_ fileName: String) -> String {
            String(localized: "Remove \(fileName)")
        }

        static func preview(_ fileName: String) -> String {
            String(localized: "Preview of \(fileName)")
        }
    }

    enum Commands {
        static var menuTitle: String { String(localized: "menu.title", defaultValue: "PDF", comment: "Menu bar menu with Beaver's PDF actions") }
        static var addPDFs: String { String(localized: "menu.addPDFs", defaultValue: "Add PDFs…") }
        static var addImages: String { String(localized: "menu.addImages", defaultValue: "Add Images…") }
        static var mergePDFs: String { String(localized: "menu.mergePDFs", defaultValue: "Merge PDFs…") }
        static var splitPDFs: String { String(localized: "menu.splitPDFs", defaultValue: "Split PDFs…") }
        static var convertToPDF: String { String(localized: "menu.convertToPDF", defaultValue: "Convert Images to PDF…") }
        static var back: String { String(localized: "menu.back", defaultValue: "Back") }
        static var clearAll: String { String(localized: "menu.clearAll", defaultValue: "Clear All…") }
    }

    enum Progress {
        static var merging: String { String(localized: "Merging PDFs…") }
        static var splitting: String { String(localized: "Splitting PDFs…") }
        static var converting: String { String(localized: "Converting images…") }
    }

    enum Confirmations {
        static func discardTitle(count: Int) -> String {
            String(localized: "Remove \(count) files from Beaver?")
        }
        static var discardMessage: String { String(localized: "The original files on disk are not changed. Rotations you made here will be lost.") }
        static var goBack: String { String(localized: "Go Back") }
        static var clearAll: String { String(localized: "Clear All") }
        static var cancel: String { String(localized: "Cancel") }
    }

    enum Alerts {
        static var success: String { String(localized: "Success") }
        static var error: String { String(localized: "Error") }
        static var ok: String { String(localized: "OK") }

        static var failedToMergePDFs: String { String(localized: "Failed to merge PDFs") }
        static var noPagesFoundToSplit: String { String(localized: "No pages found to split") }
        static var noImagesSelected: String { String(localized: "No images selected") }
        static var failedToConvertImages: String { String(localized: "Failed to convert images to PDF") }
        static var convertedImagesSuccess: String { String(localized: "Successfully converted images to PDF file") }
        static var failedToSaveAnyPDFs: String { String(localized: "Failed to save any PDF files") }

        static func mergedPDFSaved(fileName: String) -> String {
            String(localized: "Merged PDF successfully saved at \(fileName)")
        }

        static func failedToSaveMergedPDF(_ errorDescription: String) -> String {
            String(localized: "Failed to save merged PDF: \(errorDescription)")
        }

        static func failedToSaveConvertedPDF(_ errorDescription: String) -> String {
            String(localized: "Failed to save converted PDF: \(errorDescription)")
        }

        static func savedPDFFilesCount(_ count: Int) -> String {
            String(localized: "Successfully saved \(count) PDF files")
        }

        static func partialSaveSuccess(
            successCount: Int,
            failureCount: Int
        ) -> String {
            String(localized: "Partially successful: Saved \(successCount) files, failed to save \(failureCount) files")
        }

        static func skippedFiles(_ urls: [URL]) -> String {
            let names = urls.map(\.lastPathComponent).formatted(.list(type: .and))
            return String(localized: "Skipped \(urls.count) files that could not be read: \(names)")
        }

        /// Appends a note about unreadable files to `message`, if there are any.
        static func message(_ message: String, skipped urls: [URL]) -> String {
            urls.isEmpty ? message : message + "\n\n" + skippedFiles(urls)
        }

        static func message(for result: SaveResult) -> String {
            if result.isCompleteSuccess {
                return savedPDFFilesCount(result.successCount)
            }
            if result.isCompleteFailure {
                return failedToSaveAnyPDFs
            }
            return partialSaveSuccess(
                successCount: result.successCount,
                failureCount: result.failureCount
            )
        }
    }

    enum FileNames {
        static let mergedPDF = "merged.pdf"
        static let convertedImagesPDF = "ConvertedImages.pdf"
        static var saveMergedPDFPrompt: String { String(localized: "Save Merged PDF") }
        static var saveSplitPDFsPrompt: String { String(localized: "Save Split PDFs") }
        static var saveConvertedPDFPrompt: String { String(localized: "Save Converted PDF") }
    }
}
