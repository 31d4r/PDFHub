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

    @Test func windowTitleAndSubtitle() {
        #expect(DesignSystem.Workspace.title == "Beaver")
        #expect(DesignSystem.Workspace.subtitle(pdfs: 0, images: 0, selected: 0) == "No files")
        #expect(DesignSystem.Workspace.subtitle(pdfs: 3, images: 2, selected: 0) == "3 PDFs and 2 images")
        #expect(DesignSystem.Workspace.subtitle(pdfs: 3, images: 2, selected: 2) == "3 PDFs and 2 images · 2 selected")
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
        #expect(DesignSystem.Commands.menuTitle == "Actions")
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
        "help.withShortcut", "help.withDetail", "help.more", "help.quickLook", "export.addToWorkspace",
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
        #expect(DesignSystem.Help.deselectAll == "Deselect All (⌥⌘A)")
        #expect(DesignSystem.Export.cancelHelp == "Stop the export (⌘.)")
        #expect(
            DesignSystem.Help.rotateMenuItem(.left, selection: true)
                == "Rotate Selected Left (⌘L)\nRotate the selected files left"
        )
        #expect(
            DesignSystem.Help.rotateMenuItem(.right, selection: false)
                == "Rotate All Right (⇧⌘R)\nRotate every file right"
        )
    }

    /// The tooltip starts with the same words VoiceOver reads for the control.
    @Test func tooltipsMatchTheirAccessibilityLabels() {
        let pairs: [(label: String, help: String)] = [
            (DesignSystem.Workspace.addFiles, DesignSystem.Help.addFiles),
            (DesignSystem.Workspace.rotateLeft, DesignSystem.Help.rotateLeft),
            (DesignSystem.Workspace.rotateRight, DesignSystem.Help.rotateRight),
            (DesignSystem.Actions.title(.merge), DesignSystem.Help.action(.merge, .available(count: 2, selection: true))),
            (DesignSystem.Actions.title(.split), DesignSystem.Help.action(.split, .unavailable(.busy))),
            (DesignSystem.Workspace.rotateAllLeft, DesignSystem.Help.rotateMenuItem(.left, selection: false)),
            (DesignSystem.Workspace.remove, DesignSystem.Help.remove),
            (DesignSystem.Workspace.quickLook, DesignSystem.Help.quickLook),
            (DesignSystem.Pages.showPages, DesignSystem.Help.showPages),
            (DesignSystem.Pages.selectAll, DesignSystem.Help.selectAll),
            (DesignSystem.Pages.rotateSelectedLeft, DesignSystem.Help.rotateSelectedPagesLeft),
            (DesignSystem.Pages.rotateSelectedRight, DesignSystem.Help.rotateSelectedPagesRight),
            (DesignSystem.Pages.done, DesignSystem.Help.done),
        ]
        for pair in pairs {
            #expect(pair.help.hasPrefix(pair.label), "\(pair.help) doesn't start with \(pair.label)")
        }
    }
}
