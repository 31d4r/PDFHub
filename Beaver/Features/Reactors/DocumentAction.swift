import BeaverCore
import Foundation

/// The things Beaver makes from your files. Each one names exactly what it does, works on
/// the selection (or every file when nothing is selected), and says why when it can't run.
enum DocumentAction: CaseIterable, Equatable, Sendable {
    /// Two or more PDFs into one PDF.
    case merge
    /// Every page of each PDF saved as its own PDF.
    case split
    /// Images into one PDF, a page each.
    case convert
    /// PDFs and images together into one PDF, in list order.
    case combine
    /// Every page of each PDF saved as a PNG image: sharp text, larger files.
    case exportPNG
    /// Every page of each PDF saved as a JPEG image: smaller files.
    case exportJPEG

    /// Why an action can't run on the current files.
    enum Unavailable: Equatable, Sendable {
        /// An export is running, or a sheet or confirmation is open.
        case busy
        case needsTwoPDFs(selection: Bool)
        case mergeTakesOnlyPDFs
        case needsPDF(selection: Bool)
        case needsImages(selection: Bool)
        case convertTakesOnlyImages
        case needsBothKinds(selection: Bool)
        case needsPDFForImages(selection: Bool)
    }

    enum Availability: Equatable, Sendable {
        /// Runs on `count` files; `selection` tells whether they're the selection or every file.
        case available(count: Int, selection: Bool)
        case unavailable(Unavailable)

        var isAvailable: Bool {
            if case .available = self { return true }
            return false
        }
    }

    /// Whether the action can run on `targets`, which are the selection when `selection` is true.
    func availability(for targets: [WorkspaceItem], selection: Bool, isBusy: Bool) -> Availability {
        if isBusy { return .unavailable(.busy) }
        let pdfs = targets.pdfs.count
        let images = targets.images.count
        switch self {
        case .merge:
            if pdfs > 0 && images > 0 { return .unavailable(.mergeTakesOnlyPDFs) }
            return pdfs >= 2 ? .available(count: pdfs, selection: selection) : .unavailable(.needsTwoPDFs(selection: selection))
        case .split:
            return pdfs >= 1 ? .available(count: pdfs, selection: selection) : .unavailable(.needsPDF(selection: selection))
        case .convert:
            if pdfs > 0 && images > 0 { return .unavailable(.convertTakesOnlyImages) }
            return images >= 1 ? .available(count: images, selection: selection) : .unavailable(.needsImages(selection: selection))
        case .combine:
            return pdfs > 0 && images > 0
                ? .available(count: targets.count, selection: selection)
                : .unavailable(.needsBothKinds(selection: selection))
        case .exportPNG, .exportJPEG:
            return pdfs >= 1 ? .available(count: pdfs, selection: selection) : .unavailable(.needsPDFForImages(selection: selection))
        }
    }

    /// The files the action reads from `targets`: Split and the image exports skip images, the
    /// others take all.
    func sources(from targets: [WorkspaceItem]) -> [WorkspaceItem] {
        readsOnlyPDFs ? targets.filter { $0.kind == .pdf } : targets
    }

    private var readsOnlyPDFs: Bool {
        switch self {
        case .split, .exportPNG, .exportJPEG: return true
        case .merge, .convert, .combine: return false
        }
    }

    /// The image format for Export as PNG or JPEG, `nil` for the actions that make PDFs.
    var imageFormat: PageExportFormat? {
        switch self {
        case .exportPNG: return .png
        case .exportJPEG: return .jpeg
        case .merge, .split, .convert, .combine: return nil
        }
    }

    /// The suggested name in the save panel; Split asks for a folder instead, and the image
    /// exports name their files after the PDF.
    var defaultFileName: String {
        switch self {
        case .merge, .split, .exportPNG, .exportJPEG: return DesignSystem.FileNames.mergedPDF
        case .convert: return DesignSystem.FileNames.convertedImagesPDF
        case .combine: return DesignSystem.FileNames.combinedPDF
        }
    }

    var savePrompt: String {
        switch self {
        case .merge: return DesignSystem.FileNames.saveMergedPDFPrompt
        case .split: return DesignSystem.FileNames.saveSplitPDFsPrompt
        case .convert: return DesignSystem.FileNames.saveConvertedPDFPrompt
        case .combine: return DesignSystem.FileNames.saveCombinedPDFPrompt
        case .exportPNG, .exportJPEG: return DesignSystem.FileNames.saveImagesPrompt
        }
    }

    var activity: BeaverReactor.Activity {
        switch self {
        case .merge: return .merging
        case .split: return .splitting
        case .convert: return .converting
        case .combine: return .combining
        case .exportPNG, .exportJPEG: return .exportingImages
        }
    }

    /// The one-file action that fits `items`: Merge for PDFs, Convert for images, Combine for both.
    static func singleFile(for items: [WorkspaceItem]) -> DocumentAction {
        let hasPDFs = items.contains { $0.kind == .pdf }
        let hasImages = items.contains { $0.kind == .image }
        switch (hasPDFs, hasImages) {
        case (true, true): return .combine
        case (false, true): return .convert
        default: return .merge
        }
    }
}
