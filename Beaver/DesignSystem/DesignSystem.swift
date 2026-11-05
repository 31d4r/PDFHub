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
        static let destructiveButtonColor = "F56565"
        static let rotateButtonColor = "4299E1"

        static let pdfContainerBackgroundColor = "F7FAFC"
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
        static let addPDF = "Add PDF"
        static let addImages = "Add Images"
        static let splitPDFs = "Split PDFs"
        static let mergePDFs = "Merge PDFs"
        static let convertToPDF = "Convert to PDF"
        static let clearAll = "Clear All"
        static let back = "Back"
    }

    enum Text {
        static let pdfDocument = "PDF Document"
        static let beaverTitle = "Beaver"
        static let beaverSubtitle = "Your PDF workflow companion"
        static let pdfDocumentsTitle = "PDF Documents"
        static let imagesToPDFTitle = "Images to PDF"
        static let pdfButtonDescription = "Split & Merge\nPDF Files"
        static let imageButtonDescription = "Convert Images\nto PDF"

        static func pdfFilesLoadedCount(_ count: Int) -> String {
            "\(count) file\(count == 1 ? "" : "s") loaded"
        }

        static func imagesReadyCount(_ count: Int) -> String {
            "\(count) image\(count == 1 ? "" : "s") ready to convert"
        }
    }

    enum Alerts {
        static let success = "Success"
        static let error = "Error"
        static let ok = "OK"

        static let failedToMergePDFs = "Failed to merge PDFs"
        static let noPagesFoundToSplit = "No pages found to split"
        static let noImagesSelected = "No images selected"
        static let failedToConvertImages = "Failed to convert images to PDF"
        static let convertedImagesSuccess = "Successfully converted images to PDF file"
        static let failedToSaveAnyPDFs = "Failed to save any PDF files"

        static func mergedPDFSaved(fileName: String) -> String {
            "Merged PDF successfully saved at \(fileName)"
        }

        static func failedToSaveMergedPDF(_ errorDescription: String) -> String {
            "Failed to save merged PDF: \(errorDescription)"
        }

        static func failedToSaveConvertedPDF(_ errorDescription: String) -> String {
            "Failed to save converted PDF: \(errorDescription)"
        }

        static func savedPDFFilesCount(_ count: Int) -> String {
            "Successfully saved \(count) PDF file\(count == 1 ? "" : "s")"
        }

        static func partialSaveSuccess(
            successCount: Int,
            failureCount: Int
        ) -> String {
            "Partially successful: Saved \(successCount) file\(successCount == 1 ? "" : "s"), failed to save \(failureCount) file\(failureCount == 1 ? "" : "s")"
        }

        static func skippedFiles(_ urls: [URL]) -> String {
            let names = urls.map(\.lastPathComponent).joined(separator: ", ")
            return "Skipped \(urls.count) file\(urls.count == 1 ? "" : "s") that could not be read: \(names)"
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
        static let saveMergedPDFPrompt = "Save Merged PDF"
        static let saveSplitPDFsPrompt = "Save Split PDFs"
        static let saveConvertedPDFPrompt = "Save Converted PDF"
    }

    enum FileTypes {
        static let pdfExtensions = ["pdf"]
        static let fileURLType = "public.file-url"
    }
}
