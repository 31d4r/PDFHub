import Foundation
import Testing
@testable import Beaver

/// When the banner after an export goes by itself, and where Show in Files opens.
struct ExportBannerPolicyTests {
    @Test func goesByItselfOnlyWhenNothingNeedsIt() {
        #expect(ExportBannerPolicy.autoDismissDelay(isVoiceOverRunning: false, hasInteracted: false, offersChoice: false) == ExportBannerPolicy.autoDismissDelay)
        #expect(ExportBannerPolicy.autoDismissDelay(isVoiceOverRunning: true, hasInteracted: false, offersChoice: false) == nil)
        #expect(ExportBannerPolicy.autoDismissDelay(isVoiceOverRunning: false, hasInteracted: true, offersChoice: false) == nil)
        #expect(ExportBannerPolicy.autoDismissDelay(isVoiceOverRunning: false, hasInteracted: false, offersChoice: true) == nil)
        #expect(ExportBannerPolicy.autoDismissDelay >= .seconds(5))
    }

    @Test func showInFilesOpensTheFolderWithTheOutput() throws {
        let documents = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/ABC/Documents", isDirectory: true)
        let pdf = documents.appendingPathComponent("Scan 2026-11-05 07.35.pdf")

        let fileLink = try #require(ExportBannerPolicy.filesAppURL(showing: pdf, isFolder: false))
        #expect(fileLink.scheme == "shareddocuments")
        #expect(fileLink.path(percentEncoded: false).trimmingCharacters(in: ["/"]) == documents.path.trimmingCharacters(in: ["/"]))
        #expect(!fileLink.absoluteString.contains(" "))

        let pages = documents.appendingPathComponent("Receipts Pages", isDirectory: true)
        let folderLink = try #require(ExportBannerPolicy.filesAppURL(showing: pages, isFolder: true))
        #expect(folderLink.path(percentEncoded: false).trimmingCharacters(in: ["/"]) == pages.path.trimmingCharacters(in: ["/"]))

        #expect(ExportBannerPolicy.filesAppURL(showing: URL(string: "https://example.com/a.pdf")!, isFolder: false) == nil)
    }
}
