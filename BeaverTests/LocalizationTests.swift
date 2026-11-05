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
}
