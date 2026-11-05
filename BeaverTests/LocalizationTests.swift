import Foundation
import Testing
@testable import Beaver

/// Checks that the string catalog ships with the app and its plural rules apply.
struct LocalizationTests {
    @Test func workspaceSummaryPluralizesEachKind() {
        #expect(DesignSystem.Workspace.summary(pdfs: 1, images: 0) == "1 PDF")
        #expect(DesignSystem.Workspace.summary(pdfs: 3, images: 0) == "3 PDFs")
        #expect(DesignSystem.Workspace.summary(pdfs: 0, images: 1) == "1 image")
        #expect(DesignSystem.Workspace.summary(pdfs: 2, images: 5) == "2 PDFs and 5 images")
    }

    @Test func selectionSummaryCountsSelected() {
        #expect(DesignSystem.Workspace.selectionSummary(selected: 2, total: 5) == "2 of 5 selected")
    }

    @Test func partialSaveUsesBothPlurals() {
        #expect(
            DesignSystem.Alerts.partialSaveSuccess(successCount: 1, failureCount: 2)
                == "Partially successful: Saved 1 file, failed to save 2 files"
        )
    }

    @Test func skippedFilesListsNames() {
        let message = DesignSystem.Alerts.skippedFiles([URL(fileURLWithPath: "/tmp/a.pdf")])
        #expect(message == "Skipped 1 file that could not be read: a.pdf")
    }

    @Test func menuCommandsUseCatalogValues() {
        #expect(DesignSystem.Commands.menuTitle == "PDF")
        #expect(DesignSystem.Commands.addFiles == "Add Files…")
        #expect(DesignSystem.Commands.removeAll == "Remove All…")
    }

    @Test func removeAllTitlePluralizes() {
        #expect(DesignSystem.Confirmations.removeAllTitle(count: 1) == "Remove 1 file from Beaver?")
        #expect(DesignSystem.Confirmations.removeAllTitle(count: 4) == "Remove 4 files from Beaver?")
    }

    // MARK: - Tooltips

    /// Every tooltip key must be in the shipped catalog, or the tooltip falls back to the
    /// development string and never gets translated.
    @Test(arguments: [
        "help.withShortcut", "help.withDetail", "help.more", "help.thumbnailSize", "help.quickLook",
        "export.showInFinder", "export.open", "export.openFolder", "export.dismiss",
        "export.cancel", "export.showInFinder.help", "export.open.help", "export.openFolder.help",
        "export.cancel.help", "export.dismiss.help",
    ])
    func tooltipKeyIsInTheCatalog(_ key: String) {
        let missing = "\u{1}missing"
        let value = Bundle.main.localizedString(forKey: key, value: missing, table: "Localizable")
        #expect(value != missing, "\(key) is not in Localizable.xcstrings")
    }

    @Test func tooltipsNameTheActionAndItsShortcut() {
        #expect(DesignSystem.Help.rotateLeft == "Rotate Left (⌘L)")
        #expect(DesignSystem.Help.rotateRight == "Rotate Right (⌘R)")
        #expect(DesignSystem.Help.remove == "Remove (⌘⌫)")
        #expect(DesignSystem.Help.removeAll == "Remove All… (⇧⌘⌫)")
        #expect(DesignSystem.Help.showPages == "Show Pages (⌥⌘P)")
        #expect(DesignSystem.Help.quickLook == "Quick Look (Space or ⌘Y)")
        #expect(DesignSystem.Help.thumbnailSize == "Thumbnail Size (Larger ⌘+, Smaller ⌘-)")
        #expect(DesignSystem.Help.deselectAll == "Deselect All (⌥⌘A)")
        #expect(DesignSystem.Export.cancelHelp == "Stop the export (⌘.)")
        #expect(
            DesignSystem.Help.createPDF(.pdfs, selection: false)
                == "Create PDF (⌥⌘M)\nMerge all PDFs into one PDF"
        )
        #expect(
            DesignSystem.Help.splitIntoPages(selection: true)
                == "Split into Pages (⌥⌘S)\nSave each page of the selected files as its own PDF"
        )
    }

    /// The tooltip starts with the same words VoiceOver reads for the control.
    @Test func tooltipsMatchTheirAccessibilityLabels() {
        let pairs: [(label: String, help: String)] = [
            (DesignSystem.Workspace.addFiles, DesignSystem.Help.addFiles),
            (DesignSystem.Workspace.rotateLeft, DesignSystem.Help.rotateLeft),
            (DesignSystem.Workspace.rotateRight, DesignSystem.Help.rotateRight),
            (DesignSystem.Workspace.createPDF, DesignSystem.Help.createPDF(.mixed, selection: true)),
            (DesignSystem.Workspace.splitIntoPages, DesignSystem.Help.splitIntoPages(selection: false)),
            (DesignSystem.Workspace.remove, DesignSystem.Help.remove),
            (DesignSystem.Workspace.quickLook, DesignSystem.Help.quickLook),
            (DesignSystem.Workspace.thumbnailSize, DesignSystem.Help.thumbnailSize),
            (DesignSystem.Pages.showPages, DesignSystem.Help.showPages),
            (DesignSystem.Pages.selectAll, DesignSystem.Help.selectAll),
            (DesignSystem.Pages.rotateSelectedLeft, DesignSystem.Help.rotateSelectedPagesLeft),
            (DesignSystem.Pages.rotateSelectedRight, DesignSystem.Help.rotateSelectedPagesRight),
            (DesignSystem.Pages.done, DesignSystem.Help.done),
            (DesignSystem.Card.pagesRotatedBadge, DesignSystem.Help.pagesRotatedBadge),
        ]
        for pair in pairs {
            #expect(pair.help.hasPrefix(pair.label), "\(pair.help) doesn't start with \(pair.label)")
        }
    }
}
