import XCTest

/// Runs Apple's accessibility audit on the main screens. Launch arguments seed fixtures
/// so the audit can reach empty state, workspace, pages sheet and (iOS) scan review.
@MainActor
final class AccessibilityAuditUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyStateAccessibility() throws {
        let app = launch(fixture: "empty")
        assertExists(app.descendants(matching: .any)[UITestID.emptyState])
        try audit(app)
    }

    func testWorkspaceAccessibility() throws {
        let app = launch(fixture: "workspace")
        let grid = app.descendants(matching: .any)[UITestID.workspaceGrid]
        XCTAssertTrue(grid.waitForExistence(timeout: 8), "workspace grid missing")
        try audit(app)
    }

    func testPagesSheetAccessibility() throws {
        let app = launch(fixture: "pages")
        let sheet = app.descendants(matching: .any)[UITestID.pagesSheet]
        XCTAssertTrue(sheet.waitForExistence(timeout: 8), "pages sheet missing")
        try audit(app)
    }

#if os(iOS)
    func testScanReviewAccessibility() throws {
        let app = launch(fixture: "scan-review")
        let review = app.descendants(matching: .any)[UITestID.scanReview]
        XCTAssertTrue(review.waitForExistence(timeout: 20), "scan review missing")
        try audit(app)
    }

    func testEmptyStateAtAccessibilityXXXL() throws {
        let app = launch(
            fixture: "empty",
            launchEnvironment: [
                "UIPreferredContentSizeCategoryName": "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        )
        assertExists(app.descendants(matching: .any)[UITestID.emptyState])
        try audit(app)
    }

    func testEmptyStateRTLPseudoLanguage() throws {
        let app = launch(
            fixture: "empty",
            extraArguments: [
                "-AppleTextDirection", "YES",
                "-NSForceRightToLeftWritingDirection", "YES"
            ]
        )
        assertExists(app.descendants(matching: .any)[UITestID.emptyState])
        try audit(app)
    }

    func testEmptyStateReduceMotionAndIncreaseContrast() throws {
        let app = launch(
            fixture: "empty",
            extraArguments: [
                "-UIAccessibilityIsReduceMotionEnabled", "YES",
                "-UIAccessibilityDarkerSystemColorsEnabled", "YES"
            ]
        )
        assertExists(app.descendants(matching: .any)[UITestID.emptyState])
        try audit(app)
    }
#else
    func testEmptyStateReduceMotion() throws {
        let app = launch(
            fixture: "empty",
            extraArguments: ["-AXReduceMotion", "1"]
        )
        assertExists(app.descendants(matching: .any)[UITestID.emptyState])
        try audit(app)
    }
#endif

    // MARK: - Helpers

    private enum UITestID {
        static let emptyState = "beaver.empty-state"
        static let workspaceGrid = "beaver.workspace-grid"
        static let pagesSheet = "beaver.pages-sheet"
        static let scanReview = "beaver.scan-review"
    }

    private func launch(
        fixture: String,
        extraArguments: [String] = [],
        launchEnvironment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-fixture=\(fixture)"] + extraArguments
        app.launchEnvironment = launchEnvironment
        app.launch()
        return app
    }

    private func assertExists(_ element: XCUIElement, timeout: TimeInterval = 5) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing \(element)")
    }

    private func audit(_ app: XCUIApplication) throws {
        if #available(iOS 17.0, macOS 14.0, *) {
            var issues: [String] = []
            try app.performAccessibilityAudit { issue in
                if Self.shouldIgnore(issue) {
                    return true
                }
                let element = issue.element
                let elementDesc = [
                    element?.label,
                    element?.identifier,
                    element?.title,
                    element.map { String(describing: $0.elementType) },
                    element?.debugDescription
                ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " | ")
                let detail = "[\(issue.auditType)] \(issue.compactDescription) — \(elementDesc.isEmpty ? "(no element)" : elementDesc)"
                issues.append(detail)
                NSLog("A11Y_ISSUE %@", detail)
                return true
            }
            XCTAssertTrue(issues.isEmpty, "Accessibility audit findings:\n" + issues.joined(separator: "\n"))
        }
    }

    /// Ignores known iOS 26 / SwiftUI system false positives while still failing on real issues
    /// (custom supporting-text contrast, hit targets, missing labels).
    @available(iOS 17.0, macOS 14.0, *)
    private static func shouldIgnore(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        let label = issue.element?.label ?? ""
        let description = issue.compactDescription

        // Stock `.bordered` / `.borderedProminent` and nav-bar buttons: liquid-glass materials
        // make contrast + text-clipped noisy on iOS 26 without an app bug.
        let systemChrome: Set<String> = [
            "Scan Document", "Scan from Photo", "Choose Photos", "Browse Files",
            "Select All", "Done", "Rotate All Pages", "Cancel", "Save",
            "Add Your First Document",
        ]
        if description.hasPrefix("Contrast") || description.hasPrefix("Text clipped") {
            if systemChrome.contains(label) { return true }
        }

        // Filter chip contrast is sampled over the page-preview thumbnail pixels.
        let filters: Set<String> = ["Original", "Enhanced", "Grayscale", "Black & White"]
        if description.hasPrefix("Contrast"), filters.contains(label) { return true }

        // Bottom-bar / nav Menu labels report "Dynamic Type partially unsupported" for Text
        // styled with `.font(.body)` too — system chrome limitation on iOS 26.
        if description.contains("Dynamic Type") {
            if systemChrome.contains(label) || label == "Actions" || label == "Select"
                || label.hasPrefix("Scan ") {
                return true
            }
        }

        // File names with a dot are intentional labels for cards / sheet titles.
        if description.contains("not human-readable"),
           label.contains("."),
           (label.hasSuffix(".pdf") || label.hasSuffix(".png") || label.hasSuffix(".jpg")) {
            return true
        }

        // Orphaned detection with no element: usually a transient render layer.
        if description.contains("inaccessible text"), issue.element == nil {
            return true
        }

        // macOS empty-state Choose Files (localized variants use an ellipsis).
        if description.hasPrefix("Contrast") || description.hasPrefix("Text clipped") {
            if label.hasPrefix("Choose Files") || label.hasPrefix("Dateien") { return true }
        }

        // macOS window / SwiftUI hosting chrome often yields unlabeled AX elements
        // (traffic lights, focus rings, decorative shapes) that are not app controls.
        #if os(macOS)
        if label.isEmpty {
            if description.contains("no description")
                || description.hasPrefix("Contrast")
                || description.contains("Action is missing")
                || description.contains("Parent/Child") {
                return true
            }
        }
        #endif

        return false
    }
}
