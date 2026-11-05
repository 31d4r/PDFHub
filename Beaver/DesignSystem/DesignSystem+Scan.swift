import BeaverCore
import SwiftUI

/// Words and sizes for scanning on iPhone and iPad. Not behind `#if os(iOS)`, so the Mac
/// build keeps them in the String Catalog too.
extension DesignSystem {
    enum Scan {
        static let filterThumbnailSize: CGFloat = 56
        static let filterPreviewPixels = 160
        static let pagePreviewPixels = 1600
        static let cropImagePixels = 2000
        static let pageThumbnailPixels = 240
        static let handleSize: CGFloat = 28
        static let handleHitSize: CGFloat = 44
        /// How far one VoiceOver swipe moves a corner, as a share of the photo.
        static let cornerStep: Double = 0.02

        enum Icons {
            static let scan = "doc.viewfinder"
            static let scanFromPhoto = "doc.text.image"
            static let crop = "crop"
            static let rotate = "rotate.right"
            static let pages = "square.grid.2x2"
            static let addPages = "plus"
            static let retake = "camera.rotate"
            static let delete = "trash"
            static let detect = "viewfinder"
            static let wholePhoto = "arrow.up.left.and.arrow.down.right"
            static let applyToAll = "square.stack.3d.down.right"
            static let warning = "exclamationmark.triangle.fill"
            static let current = "checkmark"
            static let rename = "pencil"
            static let titleMenu = "chevron.down"
        }

        /// The start of a scan's name, before the date and time: "Scan 2026-11-04 17.05".
        static var namePrefix: String {
            String(localized: "scan.namePrefix", defaultValue: "Scan", comment: "Start of a scanned PDF's file name, followed by the date and time")
        }

        // MARK: Starting a scan

        static var scanDocument: String {
            String(localized: "scan.scanDocument", defaultValue: "Scan Document", comment: "iOS: photograph paper pages with the camera")
        }
        static var scanDocumentHelp: String {
            String(localized: "scan.scanDocument.help", defaultValue: "Photograph paper pages. Beaver finds the edges and flattens each page.", comment: "iOS: accessibility hint for Scan Document")
        }
        static var scanFromPhoto: String {
            String(localized: "scan.scanFromPhoto", defaultValue: "Scan from Photo", comment: "iOS: find and flatten a page in a photo already taken")
        }
        static var scanFromPhotoHelp: String {
            String(localized: "scan.scanFromPhoto.help", defaultValue: "Finds the page in photos you already took and flattens it.", comment: "iOS: accessibility hint for Scan from Photo")
        }
        /// Why Scan Document is dimmed in Simulator.
        static var unavailableInSimulator: String {
            String(localized: "scan.unavailable.simulator", defaultValue: "Simulator has no camera. Use Scan from Photo, or run Beaver on an iPhone or iPad.", comment: "iOS: why camera scanning is off in Simulator")
        }
        /// Why Scan Document is dimmed on a device that can't scan.
        static var unavailableOnDevice: String {
            String(localized: "scan.unavailable.device", defaultValue: "This device can't scan with its camera. Use Scan from Photo instead.", comment: "iOS: why camera scanning is off on this device")
        }

        static var cameraDeniedTitle: String {
            String(localized: "scan.cameraDenied.title", defaultValue: "Allow Camera Access", comment: "iOS alert title when the camera is off for Beaver")
        }
        static var cameraDeniedMessage: String {
            String(localized: "scan.cameraDenied.message", defaultValue: "Beaver needs the camera to scan documents. You can turn it on in Settings.", comment: "iOS alert message when the camera is off for Beaver")
        }
        static var openSettings: String {
            String(localized: "scan.openSettings", defaultValue: "Open Settings", comment: "iOS: open Beaver's page in Settings")
        }

        // MARK: Review

        static var cancel: String { String(localized: "scan.cancel", defaultValue: "Cancel", comment: "iOS: leave the scan review") }
        static var save: String { String(localized: "scan.save", defaultValue: "Save", comment: "iOS: save the reviewed scan as a PDF") }
        static var saveHelp: String {
            String(localized: "scan.save.help", defaultValue: "Saves the pages as one PDF and adds it to Beaver.", comment: "iOS: accessibility hint for Save")
        }
        static var rename: String { String(localized: "scan.rename", defaultValue: "Rename…", comment: "iOS: menu item under the scan's name") }
        static var renameHelp: String {
            String(localized: "scan.rename.help", defaultValue: "Shows a menu to rename the scan.", comment: "iOS: accessibility hint for the scan's name in the title")
        }
        static var renameTitle: String { String(localized: "scan.rename.title", defaultValue: "Rename Scan", comment: "iOS: title of the alert that renames a scan") }
        static var renameMessage: String {
            String(localized: "scan.rename.message", defaultValue: "The PDF is saved with this name.", comment: "iOS: message in the alert that renames a scan")
        }
        static var renameConfirm: String { String(localized: "scan.rename.confirm", defaultValue: "Rename", comment: "iOS: confirm the new name of a scan") }
        static var namePlaceholder: String { String(localized: "scan.name.placeholder", defaultValue: "Name", comment: "iOS: placeholder in the rename field") }
        static var done: String { String(localized: "scan.done", defaultValue: "Done", comment: "iOS: close the crop or pages screen") }

        static var discardTitle: String {
            String(localized: "scan.discard.title", defaultValue: "Discard This Scan?", comment: "iOS: confirm leaving a scan without saving")
        }
        static func discardMessage(_ count: Int) -> String {
            String(localized: "scan.discard.message", defaultValue: "The \(count) pages you scanned will be deleted.", comment: "iOS: confirm leaving a scan; count of pages")
        }
        static var discard: String { String(localized: "scan.discard", defaultValue: "Discard Scan", comment: "iOS: throw the scan away") }
        static var keepEditing: String { String(localized: "scan.keepEditing", defaultValue: "Keep Editing", comment: "iOS: go back to the scan") }

        static func pageCounter(_ number: Int, of count: Int) -> String {
            String(localized: "scan.pageCounter", defaultValue: "Page \(number) of \(count)", comment: "iOS: which page of the scan is on screen")
        }
        static func pageTitle(_ number: Int) -> String {
            String(localized: "scan.pageTitle", defaultValue: "Page \(number)", comment: "iOS: one page of a scan")
        }

        static var preparing: String { String(localized: "scan.preparing", defaultValue: "Finding Pages…", comment: "iOS: shown while new scan pages are prepared") }
        static var saving: String { String(localized: "scan.saving", defaultValue: "Saving PDF…", comment: "iOS: shown while the scan is written") }

        static var noPagesTitle: String { String(localized: "scan.noPages.title", defaultValue: "No Pages", comment: "iOS: the scan has no pages left") }
        static var noPagesMessage: String {
            String(localized: "scan.noPages.message", defaultValue: "Scan pages or add photos of them to make a PDF.", comment: "iOS: the scan has no pages left")
        }

        static func pagesFailed(_ count: Int) -> String {
            String(localized: "scan.pagesFailed", defaultValue: "\(count) pages couldn't be added.", comment: "iOS alert when scanned pages can't be stored; count of pages")
        }
        static var saveFailed: String {
            String(localized: "scan.saveFailed", defaultValue: "The scan couldn't be saved. Make sure there's space on this device, then try again.", comment: "iOS alert when the scanned PDF can't be written")
        }
        static func saved(fileName: String) -> String {
            String(localized: "scan.saved", defaultValue: "Saved “\(fileName)” in Beaver’s folder in Files", comment: "iOS banner after a scan is saved; the file name")
        }

        // MARK: Text recognition

        static var makeTextSearchable: String {
            String(localized: "scan.makeTextSearchable", defaultValue: "Make Text Searchable", comment: "Toggle: add invisible OCR text so the PDF can be searched and copied")
        }
        static var makeTextSearchableHelp: String {
            String(localized: "scan.makeTextSearchable.help", defaultValue: "Adds invisible text so you can search and copy from the PDF in Files and Preview.", comment: "Accessibility hint for Make Text Searchable")
        }
        static var copyText: String {
            String(localized: "scan.copyText", defaultValue: "Copy Text", comment: "Copy the text Vision read from the page")
        }
        static var recognizedText: String {
            String(localized: "scan.recognizedText", defaultValue: "Recognized Text", comment: "Sheet title: the text Vision read from the page")
        }
        static var recognizedTextHelp: String {
            String(localized: "scan.recognizedText.help", defaultValue: "Shows the text Beaver read from this page.", comment: "Accessibility hint for Recognized Text")
        }
        static var recognizingText: String {
            String(localized: "scan.recognizingText", defaultValue: "Reading Text…", comment: "Shown while Vision reads text from a page")
        }
        static var noTextFound: String {
            String(localized: "scan.noTextFound", defaultValue: "No text found on this page.", comment: "When Vision finds no text on a scanned page")
        }
        static var shareText: String {
            String(localized: "scan.shareText", defaultValue: "Share Text", comment: "Share the text Vision read from the page")
        }
        static var textCopied: String {
            String(localized: "scan.textCopied", defaultValue: "Text Copied", comment: "VoiceOver / confirmation after copying recognized text")
        }

        // MARK: Filters

        static var filter: String { String(localized: "scan.filter", defaultValue: "Filter", comment: "iOS: the row of looks for a scanned page") }

        static func filterName(_ filter: ScanFilter) -> String {
            switch filter {
            case .original:
                return String(localized: "scan.filter.original", defaultValue: "Original", comment: "Scan filter: the photo as taken")
            case .enhanced:
                return String(localized: "scan.filter.enhanced", defaultValue: "Enhanced", comment: "Scan filter: no shadows, white paper, crisp colour")
            case .grayscale:
                return String(localized: "scan.filter.grayscale", defaultValue: "Grayscale", comment: "Scan filter: enhanced, without colour")
            case .blackAndWhite:
                return String(localized: "scan.filter.blackAndWhite", defaultValue: "Black & White", comment: "Scan filter: only ink and paper")
            }
        }

        static func filterHelp(_ filter: ScanFilter) -> String {
            switch filter {
            case .original:
                return String(localized: "scan.filter.original.help", defaultValue: "Keeps the photo as it was taken.", comment: "Scan filter hint")
            case .enhanced:
                return String(localized: "scan.filter.enhanced.help", defaultValue: "Removes shadows and makes the paper white. Best for most pages.", comment: "Scan filter hint")
            case .grayscale:
                return String(localized: "scan.filter.grayscale.help", defaultValue: "Like Enhanced, in shades of grey.", comment: "Scan filter hint")
            case .blackAndWhite:
                return String(localized: "scan.filter.blackAndWhite.help", defaultValue: "Only black ink on white paper. Best for text, smallest file.", comment: "Scan filter hint")
            }
        }

        static var applyToAll: String { String(localized: "scan.applyToAll", defaultValue: "Apply to All", comment: "iOS: give every page this filter") }
        static var applyToAllHelp: String {
            String(localized: "scan.applyToAll.help", defaultValue: "Gives every page the filter of this page.", comment: "iOS: accessibility hint for Apply to All")
        }

        // MARK: Page actions

        static var crop: String { String(localized: "scan.crop", defaultValue: "Crop", comment: "iOS: move the corners of a scanned page") }
        static var cropHelp: String {
            String(localized: "scan.crop.help", defaultValue: "Move the corners to the edges of the page.", comment: "iOS: accessibility hint for Crop")
        }
        static var rotate: String { String(localized: "scan.rotate", defaultValue: "Rotate", comment: "iOS: turn a scanned page") }
        static var rotateHelp: String {
            String(localized: "scan.rotate.help", defaultValue: "Turns the page a quarter turn clockwise.", comment: "iOS: accessibility hint for Rotate")
        }
        static var pages: String { String(localized: "scan.pages", defaultValue: "Pages", comment: "iOS: see, reorder and delete the pages of a scan") }
        static var pagesHelp: String {
            String(localized: "scan.pages.help", defaultValue: "Reorder or delete pages.", comment: "iOS: accessibility hint for Pages")
        }
        static var addPages: String { String(localized: "scan.addPages", defaultValue: "Add", comment: "iOS menu that adds pages to a scan") }
        static var scanMorePages: String { String(localized: "scan.scanMore", defaultValue: "Scan More Pages", comment: "iOS: add pages to the scan with the camera") }
        static var addFromPhotos: String { String(localized: "scan.addFromPhotos", defaultValue: "Add from Photos", comment: "iOS: add pages to the scan from the photo library") }
        static var retake: String { String(localized: "scan.retake", defaultValue: "Retake This Page", comment: "iOS: photograph the page on screen again") }
        static var deletePage: String { String(localized: "scan.deletePage", defaultValue: "Delete Page", comment: "iOS: remove the page on screen from the scan") }

        // MARK: Crop

        static var cropTitle: String { String(localized: "scan.crop.title", defaultValue: "Crop Page", comment: "iOS: title of the corner editor") }
        static var findPage: String { String(localized: "scan.findPage", defaultValue: "Find Page", comment: "iOS: let Vision find the page edges again") }
        static var findPageHelp: String {
            String(localized: "scan.findPage.help", defaultValue: "Looks for the edges of the page in the photo.", comment: "iOS: accessibility hint for Find Page")
        }
        static var wholePhoto: String { String(localized: "scan.wholePhoto", defaultValue: "Whole Photo", comment: "iOS: use the whole photo as the page") }
        static var wholePhotoHelp: String {
            String(localized: "scan.wholePhoto.help", defaultValue: "Moves the corners to the corners of the photo.", comment: "iOS: accessibility hint for Whole Photo")
        }
        static var cropInstructions: String {
            String(localized: "scan.crop.instructions", defaultValue: "Drag the corners to the edges of the page.", comment: "iOS: how to use the corner editor")
        }
        static var noPageFound: String {
            String(localized: "scan.noPageFound", defaultValue: "No page found. Drag the corners to the edges of the page.", comment: "iOS: Vision found no page")
        }
        static var cornersCross: String {
            String(localized: "scan.cornersCross", defaultValue: "The edges cross. Move the corners so they outline the page.", comment: "iOS: why Done is off in the corner editor")
        }

        static func cornerName(_ corner: DocumentQuad.Corner) -> String {
            switch corner {
            case .topLeft:
                return String(localized: "scan.corner.topLeft", defaultValue: "Top-left corner", comment: "VoiceOver: a corner handle")
            case .topRight:
                return String(localized: "scan.corner.topRight", defaultValue: "Top-right corner", comment: "VoiceOver: a corner handle")
            case .bottomRight:
                return String(localized: "scan.corner.bottomRight", defaultValue: "Bottom-right corner", comment: "VoiceOver: a corner handle")
            case .bottomLeft:
                return String(localized: "scan.corner.bottomLeft", defaultValue: "Bottom-left corner", comment: "VoiceOver: a corner handle")
            }
        }

        /// Where a corner is, for VoiceOver: "20% from left, 15% from top".
        static func cornerPosition(fromLeft: Int, fromTop: Int) -> String {
            String(localized: "scan.corner.position", defaultValue: "\(fromLeft)% from left, \(fromTop)% from top", comment: "VoiceOver: where a corner handle is")
        }
        static var moveUp: String { String(localized: "scan.move.up", defaultValue: "Move Up", comment: "VoiceOver action on a corner handle") }
        static var moveDown: String { String(localized: "scan.move.down", defaultValue: "Move Down", comment: "VoiceOver action on a corner handle") }
        static var moveLeft: String { String(localized: "scan.move.left", defaultValue: "Move Left", comment: "VoiceOver action on a corner handle") }
        static var moveRight: String { String(localized: "scan.move.right", defaultValue: "Move Right", comment: "VoiceOver action on a corner handle") }
    }
}
