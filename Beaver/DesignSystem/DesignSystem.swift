import BeaverCore
import SwiftUI

/// Beaver's look and words. Colors, materials and type come from the system so the app
/// follows Dark Mode, the accent color, Increase Contrast and Reduce Transparency for free;
/// what's left here is sizing and every string people see.
enum DesignSystem {
    enum Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let contentPadding: CGFloat = 20
        static let gridSpacing: CGFloat = 20
    }

    enum Layout {
        static let windowDefaultSize = CGSize(width: 1080, height: 720)
        static let windowMinimumSize = CGSize(width: 640, height: 460)
        static let thumbnailRadius: CGFloat = 8
        static let selectionRadius: CGFloat = 10
        static let rotateAnimationDuration: Double = 0.3
        /// The thumbnail edge in points, and the steps of the size slider and ⌘+ / ⌘-.
        static let thumbnailSizeRange: ClosedRange<Double> = 96...320
        static let thumbnailSizeStep: Double = 32
        static let defaultThumbnailSize: Double = 160
        static let thumbnailSizeKey = "thumbnailSize"
        /// Twice the largest thumbnail, for Retina.
        static let previewPixelSize = 640
    }

    enum Icons {
        static let addFiles = "plus"
        static let rotateLeft = "rotate.left"
        static let rotateRight = "rotate.right"
        static let remove = "trash"
        static let more = "ellipsis.circle"
        static let createPDF = "doc.badge.plus"
        static let splitIntoPages = "square.split.2x1"
        static let pages = "square.grid.2x2"
        static let quickLook = "eye"
        static let pdf = "doc.richtext"
        static let image = "photo"
        static let thumbnailSmall = "square.grid.3x3"
        static let thumbnailLarge = "square.grid.2x2"
        static let selectedPage = "checkmark.circle.fill"
        static let pagesRotated = "rotate.right.fill"
        static let unreadable = "doc.questionmark"
    }

    /// The window and its toolbar.
    enum Workspace {
        static var title: String { String(localized: "Files", comment: "Window title of Beaver's file list") }
        static var emptySubtitle: String { String(localized: "No files", comment: "Window subtitle when the list is empty") }

        /// "3 PDFs and 2 images"
        static func summary(pdfs: Int, images: Int) -> String {
            var parts: [String] = []
            if pdfs > 0 { parts.append(String(localized: "\(pdfs) PDFs")) }
            if images > 0 { parts.append(String(localized: "\(images) images")) }
            return parts.formatted(.list(type: .and))
        }

        /// "2 of 5 selected"
        static func selectionSummary(selected: Int, total: Int) -> String {
            String(localized: "\(selected) of \(total) selected")
        }

        static var addFiles: String { String(localized: "Add Files…") }
        static var addFilesHelp: String { String(localized: "Add PDFs and images") }
        static var rotateLeft: String { String(localized: "Rotate Left") }
        static var rotateRight: String { String(localized: "Rotate Right") }
        static var rotate: String { String(localized: "Rotate") }
        static var remove: String { String(localized: "Remove") }
        static var removeAll: String { String(localized: "Remove All…") }
        static var more: String { String(localized: "More") }
        static var thumbnailSize: String { String(localized: "Thumbnail Size") }
        static var createPDF: String { String(localized: "Create PDF") }
        static var splitIntoPages: String { String(localized: "Split into Pages") }
        static var quickLook: String { String(localized: "Quick Look") }

        static func rotateHelp(_ direction: RotationDirection, selection: Bool) -> String {
            switch (direction, selection) {
            case (.left, true): return String(localized: "Rotate the selected files left")
            case (.left, false): return String(localized: "Rotate all files left")
            case (.right, true): return String(localized: "Rotate the selected files right")
            case (.right, false): return String(localized: "Rotate all files right")
            }
        }


        static func createPDFHelp(_ kind: ExportKind, selection: Bool) -> String {
            switch (kind, selection) {
            case (.pdfs, true): return String(localized: "Merge the selected PDFs into one PDF")
            case (.pdfs, false): return String(localized: "Merge all PDFs into one PDF")
            case (.images, true): return String(localized: "Turn the selected images into one PDF")
            case (.images, false): return String(localized: "Turn all images into one PDF")
            case (.mixed, true): return String(localized: "Combine the selected files into one PDF")
            case (.mixed, false): return String(localized: "Combine all files into one PDF")
            }
        }

        static func splitHelp(selection: Bool) -> String {
            selection
                ? String(localized: "Save each page of the selected files as its own PDF")
                : String(localized: "Save each page of all files as its own PDF")
        }
    }

    /// The first-run drop target.
    enum EmptyState {
        static var title: String { String(localized: "Drop PDFs and Images Here") }
        static var message: String {
            String(localized: "Merge PDFs, split them into pages, or turn images into a PDF. Your originals are never changed.")
        }
        static var chooseFiles: String { String(localized: "Choose Files…") }
        static var dropToAdd: String { String(localized: "Release to Add") }
        static var hintChoose: String { String(localized: "hint.choose", defaultValue: "Choose files", comment: "Empty state shortcut hint next to ⌘O") }
        static var hintReorder: String { String(localized: "Drag to reorder") }
        static var hintQuickLook: String { String(localized: "Quick Look") }
        static var hintDragKey: String { String(localized: "Drag", comment: "Shown like a key cap next to 'Drag to reorder'") }
        static var hintSpaceKey: String { String(localized: "Space", comment: "The space bar, shown like a key cap") }
    }

    /// One file in the grid.
    enum Card {
        static var pdfKind: String { String(localized: "PDF") }
        static var pagesRotatedBadge: String { String(localized: "Pages rotated") }

        /// "PDF · 12 pages"
        static func pdfMeta(pageCount: Int?) -> String {
            guard let pageCount else { return pdfKind }
            return "\(pdfKind) · \(Pages.pageCount(pageCount))"
        }

        /// "PNG · 1200 × 800"
        static func imageMeta(fileExtension: String, pixelSize: CGSize?) -> String {
            let kind = fileExtension.uppercased()
            guard let pixelSize else { return kind }
            return "\(kind) · \(Int(pixelSize.width)) × \(Int(pixelSize.height))"
        }

        /// "report.pdf, PDF · 12 pages, Rotated 90 degrees"
        static func accessibilityLabel(name: String, meta: String, rotation: RotationAngle) -> String {
            [name, meta, Accessibility.rotation(rotation)].filter { !$0.isEmpty }.joined(separator: ", ")
        }
    }

    enum Accessibility {
        static func rotateLeft(_ fileName: String) -> String {
            String(localized: "Rotate \(fileName) left")
        }

        static func rotateRight(_ fileName: String) -> String {
            String(localized: "Rotate \(fileName) right")
        }

        /// Read after a file's name, e.g. "Rotated 90 degrees". Empty when upright.
        static func rotation(_ angle: RotationAngle) -> String {
            angle == .zero ? "" : String(localized: "Rotated \(angle.degrees) degrees")
        }

        static var fileList: String { String(localized: "Files") }
        static var dropTargetHint: String { String(localized: "Drop PDFs and images here, or choose files") }
    }

    /// The page view of one PDF.
    enum Pages {
        static var showPages: String { String(localized: "Show Pages") }
        static var selectAll: String { String(localized: "Select All") }
        static var rotateSelectedLeft: String { String(localized: "Rotate Selected Left") }
        static var rotateSelectedRight: String { String(localized: "Rotate Selected Right") }
        static var rotateAllPages: String { String(localized: "Rotate All Pages") }
        static var rotateAllPagesLeft: String { String(localized: "Rotate All Pages Left") }
        static var rotateAllPagesRight: String { String(localized: "Rotate All Pages Right") }
        static var done: String { String(localized: "Done") }
        static var unreadable: String { String(localized: "Beaver couldn’t read the pages of this PDF.") }
        static var selectionHint: String {
            String(localized: "Click to select, ⌘-click to add or remove, ⇧-click for a range.")
        }
        static var pagesRotatedBadge: String { String(localized: "Pages rotated") }
        static var pagesRotatedBadgeHelp: String { String(localized: "Some pages have their own rotation") }

        static func title(_ fileName: String) -> String {
            String(localized: "Pages of \(fileName)")
        }

        static func pageCount(_ count: Int) -> String {
            String(localized: "\(count) pages")
        }

        static func selectedCount(_ count: Int) -> String {
            String(localized: "\(count) selected")
        }

        /// `index` is zero-based; people see page numbers from 1.
        static func page(_ index: Int) -> String {
            String(localized: "Page \(index + 1)")
        }

        /// "Page 3, rotated 90 degrees", or "Page 3" when upright.
        static func pageAccessibilityLabel(_ index: Int, rotation: RotationAngle) -> String {
            rotation == .zero
                ? page(index)
                : String(localized: "Page \(index + 1), rotated \(rotation.degrees) degrees")
        }
    }

    /// Labels for moving a card. "Left" and "Right" follow the grid's reading order.
    enum Reorder {
        static var moveToBeginning: String { String(localized: "Move to Beginning") }
        static var moveLeft: String { String(localized: "Move Left") }
        static var moveRight: String { String(localized: "Move Right") }
        static var moveToEnd: String { String(localized: "Move to End") }
    }

    enum Commands {
        static var menuTitle: String { String(localized: "menu.title", defaultValue: "PDF", comment: "Menu bar menu with Beaver's PDF actions") }
        static var addFiles: String { String(localized: "menu.addFiles", defaultValue: "Add Files…") }
        static var createPDF: String { String(localized: "menu.createPDF", defaultValue: "Create PDF…") }
        static var splitIntoPages: String { String(localized: "menu.splitIntoPages", defaultValue: "Split into Pages…") }
        static var showPages: String { String(localized: "menu.showPages", defaultValue: "Show Pages") }
        static var quickLook: String { String(localized: "menu.quickLook", defaultValue: "Quick Look") }
        static var rotateLeft: String { String(localized: "menu.rotateLeft", defaultValue: "Rotate Left") }
        static var rotateRight: String { String(localized: "menu.rotateRight", defaultValue: "Rotate Right") }
        static var rotateAllLeft: String { String(localized: "menu.rotateAllLeft", defaultValue: "Rotate All Left") }
        static var rotateAllRight: String { String(localized: "menu.rotateAllRight", defaultValue: "Rotate All Right") }
        static var remove: String { String(localized: "menu.remove", defaultValue: "Remove") }
        static var removeAll: String { String(localized: "menu.removeAll", defaultValue: "Remove All…") }
        static var deselectAll: String { String(localized: "menu.deselectAll", defaultValue: "Deselect All") }
        static var largerThumbnails: String { String(localized: "menu.largerThumbnails", defaultValue: "Make Thumbnails Larger") }
        static var smallerThumbnails: String { String(localized: "menu.smallerThumbnails", defaultValue: "Make Thumbnails Smaller") }
        static var undo: String { String(localized: "menu.undo", defaultValue: "Undo") }
        static var redo: String { String(localized: "menu.redo", defaultValue: "Redo") }
        /// The name of an undoable change, shown after "Undo" or "Redo".
        static var addEditName: String { String(localized: "menu.edit.add", defaultValue: "Add Files") }
        static var removeEditName: String { String(localized: "menu.edit.remove", defaultValue: "Remove") }
        static var removeAllEditName: String { String(localized: "menu.edit.removeAll", defaultValue: "Remove All") }
        static var moveEditName: String { String(localized: "menu.edit.move", defaultValue: "Move") }
        static var rotateEditName: String { String(localized: "menu.edit.rotate", defaultValue: "Rotate") }
        static var rotateAllEditName: String { String(localized: "menu.edit.rotateAll", defaultValue: "Rotate All") }
        static var rotatePagesEditName: String { String(localized: "menu.edit.rotatePages", defaultValue: "Rotate Pages") }
        static var rotateAllPagesEditName: String { String(localized: "menu.edit.rotateAllPages", defaultValue: "Rotate All Pages") }

        static func undo(_ editName: String) -> String {
            String(localized: "menu.undoNamed", defaultValue: "Undo \(editName)", comment: "Edit menu, e.g. Undo Rotate All")
        }

        static func redo(_ editName: String) -> String {
            String(localized: "menu.redoNamed", defaultValue: "Redo \(editName)", comment: "Edit menu, e.g. Redo Rotate All")
        }
    }

    enum Progress {
        static var merging: String { String(localized: "Merging PDFs…") }
        static var splitting: String { String(localized: "Splitting into pages…") }
        static var converting: String { String(localized: "Converting images…") }
        static var combining: String { String(localized: "Creating PDF…") }
    }

    enum Confirmations {
        static func removeAllTitle(count: Int) -> String {
            String(localized: "Remove \(count) files from Beaver?")
        }
        static func removeAllMessage(includesRotations: Bool) -> String {
            includesRotations
                ? String(localized: "Your original files aren’t changed. You can undo this, including the rotations you made.")
                : String(localized: "Your original files aren’t changed. You can undo this.")
        }
        static var removeAll: String { String(localized: "confirm.removeAll", defaultValue: "Remove All", comment: "Destructive button in the Remove All confirmation") }
        static var cancel: String { String(localized: "Cancel") }
    }

    enum Alerts {
        static var success: String { String(localized: "Success") }
        static var error: String { String(localized: "Error") }
        static var ok: String { String(localized: "OK") }

        static var failedToMergePDFs: String { String(localized: "Failed to merge PDFs") }
        static var noPagesFoundToSplit: String { String(localized: "No pages found to split") }
        static var failedToCombine: String { String(localized: "Couldn’t create the PDF") }
        static var failedToConvertImages: String { String(localized: "Failed to convert images to PDF") }
        static var convertedImagesSuccess: String { String(localized: "Successfully converted images to PDF file") }
        static var failedToSaveAnyPDFs: String { String(localized: "Failed to save any PDF files") }

        static func mergedPDFSaved(fileName: String) -> String {
            String(localized: "Merged PDF successfully saved at \(fileName)")
        }

        static func combinedPDFSaved(fileName: String) -> String {
            String(localized: "Saved \(fileName)")
        }

        static func failedToSaveCombinedPDF(_ errorDescription: String) -> String {
            String(localized: "Failed to save PDF: \(errorDescription)")
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
        static let combinedPDF = "Combined.pdf"
        static var saveMergedPDFPrompt: String { String(localized: "Save Merged PDF") }
        static var saveSplitPDFsPrompt: String { String(localized: "Save Split PDFs") }
        static var saveConvertedPDFPrompt: String { String(localized: "Save Converted PDF") }
        static var saveCombinedPDFPrompt: String { String(localized: "Save PDF") }
        static var addFilesPrompt: String { String(localized: "Add") }
    }
}
