import Foundation
import Testing
@testable import Beaver

/// Checks that the string catalog ships with the app and its plural rules apply.
struct LocalizationTests {
    @Test func fileCountPluralizes() {
        #expect(DesignSystem.Text.pdfFilesLoadedCount(1) == "1 file loaded")
        #expect(DesignSystem.Text.pdfFilesLoadedCount(3) == "3 files loaded")
    }

    @Test func imageCountPluralizes() {
        #expect(DesignSystem.Text.imagesReadyCount(1) == "1 image ready to convert")
        #expect(DesignSystem.Text.imagesReadyCount(2) == "2 images ready to convert")
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

    @Test func discardTitlePluralizes() {
        #expect(DesignSystem.Confirmations.discardTitle(count: 1) == "Remove 1 file from Beaver?")
        #expect(DesignSystem.Confirmations.discardTitle(count: 4) == "Remove 4 files from Beaver?")
    }
}
