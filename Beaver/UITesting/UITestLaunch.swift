import BeaverCore
import Foundation

/// Launch-argument hooks used only by BeaverUITests. Production launches never set these.
enum UITestLaunch {
    static let testingArgument = "-ui-testing"
    static let fixtureArgumentPrefix = "-ui-fixture="

    enum Fixture: String {
        case empty
        case workspace
        case pages
        case scanReview = "scan-review"
    }

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(testingArgument)
    }

    static var fixture: Fixture {
        guard isEnabled else { return .empty }
        let value = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix(fixtureArgumentPrefix) }?
            .dropFirst(fixtureArgumentPrefix.count)
        return value.flatMap { Fixture(rawValue: String($0)) } ?? .empty
    }

    /// Copies bundled UI-test fixtures into a private temp folder so the sandbox can read them.
    static func materializeFixtures() -> (pdf: URL, pdf2: URL, image: URL)? {
        guard
            let pdfSource = Bundle.main.url(forResource: "sample", withExtension: "pdf", subdirectory: "Fixtures")
                ?? Bundle.main.url(forResource: "sample", withExtension: "pdf"),
            let imageSource = Bundle.main.url(forResource: "sample", withExtension: "png", subdirectory: "Fixtures")
                ?? Bundle.main.url(forResource: "sample", withExtension: "png")
        else { return nil }

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("BeaverUITestFixtures", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let pdf = folder.appendingPathComponent("sample.pdf")
        let pdf2 = folder.appendingPathComponent("sample-2.pdf")
        let image = folder.appendingPathComponent("sample.png")
        for (source, destination) in [(pdfSource, pdf), (pdfSource, pdf2), (imageSource, image)] {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.copyItem(at: source, to: destination)
        }
        return (pdf, pdf2, image)
    }

    /// Seeds the workspace (and optionally opens the page sheet) for UI audits.
    @MainActor
    static func prepareWorkspace(reactor: BeaverReactor) {
        guard isEnabled else { return }
        switch fixture {
        case .empty:
            break
        case .workspace, .pages:
            guard let urls = materializeFixtures() else { return }
            reactor.action(.setPDFs([
                PDFItem(url: urls.pdf),
                PDFItem(url: urls.pdf2)
            ]))
            if fixture == .pages, let id = reactor.state.pdfs.first?.id {
                reactor.action(.showPages(id: id))
            }
        case .scanReview:
            break // handled by MobileMainView on iOS
        }
    }

    /// File URLs for a fixture scan review, when the scan-review fixture is active.
    static func scanReviewImageURLs() -> [URL] {
        guard isEnabled, fixture == .scanReview, let urls = materializeFixtures() else { return [] }
        return [urls.image]
    }
}

/// Stable accessibility identifiers for UI tests.
enum UITestID {
    static let emptyState = "beaver.empty-state"
    static let workspaceGrid = "beaver.workspace-grid"
    static let pagesSheet = "beaver.pages-sheet"
    static let scanReview = "beaver.scan-review"
}
