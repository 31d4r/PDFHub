import BeaverCore
import Foundation
import Testing
@testable import Beaver

/// The card's rotation badge and the page sheet's rotate buttons, so a turned file is never silent.
@MainActor
struct RotationBadgeTests {
    @Test func unturnedFilesHaveNoBadge() {
        #expect(DesignSystem.Card.rotatedBadge(file: .zero, rotatedPages: 0) == nil)
    }

    @Test func badgeSaysHowTheFileIsTurned() {
        #expect(DesignSystem.Card.rotatedBadge(file: .ninety, rotatedPages: 0) == "Rotated 90°")
        #expect(DesignSystem.Card.rotatedBadge(file: .zero, rotatedPages: 1) == "1 page rotated")
        #expect(DesignSystem.Card.rotatedBadge(file: .zero, rotatedPages: 3) == "3 pages rotated")
        #expect(DesignSystem.Card.rotatedBadge(file: .twoSeventy, rotatedPages: 2) == "Rotated 270°, 2 pages rotated")
        #expect(DesignSystem.Card.rotatedBadgeLabel(.oneEighty) == "180°")
    }

    @Test func rotatedFilesOfEitherKindGetABadge() async {
        let reactor = BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: MockImageService(),
            exportService: MockExportService()
        )
        await reactor.action(.addFiles([TestFixtures.samplePDF, TestFixtures.samplePNG]))
        reactor.action(.rotateAll(.right))
        for item in reactor.state.items {
            #expect(DesignSystem.Card.rotatedBadge(file: item.rotationAngle, rotatedPages: 0) == "Rotated 90°")
        }
    }

    @Test func pageRotateButtonsExplainWhenTheyAreDimmed() {
        #expect(DesignSystem.Pages.rotateLeft == "Rotate Left")
        #expect(DesignSystem.Pages.rotateRight == "Rotate Right")
        #expect(DesignSystem.Help.rotatePages(.left, hasSelection: true) == DesignSystem.Help.rotateSelectedPagesLeft)
        #expect(DesignSystem.Help.rotatePages(.right, hasSelection: true) == DesignSystem.Help.rotateSelectedPagesRight)
        let dimmed = DesignSystem.Help.rotatePages(.left, hasSelection: false)
        #expect(dimmed.hasPrefix(DesignSystem.Help.rotateSelectedPagesLeft))
        #expect(dimmed.contains(DesignSystem.Pages.rotateSelectionHint))
    }

    @Test func pageSheetTitleIsTheFullFileName() {
        #expect(DesignSystem.Pages.title("Quarterly report final.pdf") == "Quarterly report final.pdf")
        #expect(DesignSystem.Pages.pageCount(3) == "3 pages")
    }

    @Test func badgeAndPageKeysAreInTheCatalog() {
        for key in [
            "card.rotated", "card.pagesRotated", "card.rotatedWithPages", "card.rotatedLabel",
            "pages.rotateLeft", "pages.rotateRight", "pages.rotateSelection.disabled",
        ] {
            #expect(Bundle.main.localizedString(forKey: key, value: "\u{1}missing", table: "Localizable") != "\u{1}missing", "\(key)")
        }
    }
}
