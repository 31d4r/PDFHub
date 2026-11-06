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


    // MARK: - Catalog completeness

    /// Every user-facing key must ship de, bs, hr, sr-Latn, es, pt-BR, ru, zh-Hans and fr
    /// with matching format tokens and the plural categories each locale needs.
    @Test func everyKeyHasAllShippedLocalizations() throws {
        let catalogURL = try #require(Self.localizableCatalogURL())
        let data = try Data(contentsOf: catalogURL)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: Any])
        let required = ["de", "bs", "hr", "sr-Latn", "es", "pt-BR", "ru", "zh-Hans", "fr"]
        let pluralForms: [String: Set<String>] = [
            "de": ["one", "other"],
            "bs": ["one", "few", "other"],
            "hr": ["one", "few", "other"],
            "sr-Latn": ["one", "few", "other"],
            "es": ["one", "many", "other"],
            "pt-BR": ["one", "many", "other"],
            "ru": ["one", "few", "many", "other"],
            "zh-Hans": ["other"],
            "fr": ["one", "many", "other"],
        ]
        var problems: [String] = []
        for (key, raw) in strings {
            guard let entry = raw as? [String: Any] else { continue }
            let locs = entry["localizations"] as? [String: Any] ?? [:]
            guard let en = locs["en"] as? [String: Any] else {
                problems.append("\(key): missing en")
                continue
            }
            let enTokens = Self.formatTokens(in: Self.primaryValue(en))
            for lang in required {
                guard let loc = locs[lang] as? [String: Any] else {
                    problems.append("\(key): missing \(lang)")
                    continue
                }
                if let variations = loc["variations"] as? [String: Any],
                   let plural = variations["plural"] as? [String: Any] {
                    let needed = pluralForms[lang] ?? ["one", "other"]
                    let have = Set(plural.keys)
                    if !needed.isSubset(of: have) {
                        problems.append("\(key): \(lang) forms \(have.sorted()) missing \(needed.subtracting(have))")
                    }
                    for form in needed {
                        guard let node = plural[form] as? [String: Any],
                              let unit = node["stringUnit"] as? [String: Any],
                              let value = unit["value"] as? String else {
                            problems.append("\(key): \(lang).\(form) missing value")
                            continue
                        }
                        let tokens = Self.formatTokens(in: value)
                        // Compare against the English form of the same name when present, else "other".
                        let enPlural = (en["variations"] as? [String: Any])?["plural"] as? [String: Any]
                        let enForm = (enPlural?[form] ?? enPlural?["other"] ?? enPlural?["one"]) as? [String: Any]
                        let enValue = (enForm?["stringUnit"] as? [String: Any])?["value"] as? String
                            ?? Self.primaryValue(en)
                        if Self.formatTokens(in: enValue) != tokens {
                            problems.append("\(key): \(lang).\(form) tokens \(tokens) != \(Self.formatTokens(in: enValue))")
                        }
                        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !enValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            problems.append("\(key): \(lang).\(form) empty")
                        }
                    }
                } else if let unit = loc["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
                    if Self.formatTokens(in: value) != enTokens {
                        problems.append("\(key): \(lang) tokens \(Self.formatTokens(in: value)) != \(enTokens)")
                    }
                    let enValue = Self.primaryValue(en)
                    if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       !enValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        problems.append("\(key): \(lang) empty")
                    }
                } else {
                    problems.append("\(key): \(lang) has no stringUnit or plural")
                }
            }
        }
        #expect(problems.isEmpty, "\(problems.prefix(20).joined(separator: "\n"))\(problems.count > 20 ? "\n… +\(problems.count - 20) more" : "")")
    }

    /// Spot-check catalog plural copy for the new locales (CLDR categories, not Bundle lookup).
    @Test func newLocalePagePluralsMatchExpectedCopy() throws {
        let catalogURL = try #require(Self.localizableCatalogURL())
        let data = try Data(contentsOf: catalogURL)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(json["strings"] as? [String: Any])
        let entry = try #require(strings["%lld pages"] as? [String: Any])
        let locs = try #require(entry["localizations"] as? [String: Any])

        func form(_ lang: String, _ name: String) throws -> String {
            let loc = try #require(locs[lang] as? [String: Any])
            let plural = try #require((loc["variations"] as? [String: Any])?["plural"] as? [String: Any])
            let node = try #require(plural[name] as? [String: Any])
            let unit = try #require(node["stringUnit"] as? [String: Any])
            return try #require(unit["value"] as? String)
        }

        #expect(try form("es", "one") == "%lld página")
        #expect(try form("es", "other") == "%lld páginas")
        #expect(try form("es", "many") == "%lld páginas")
        #expect(try form("pt-BR", "one") == "%lld página")
        #expect(try form("pt-BR", "other") == "%lld páginas")
        #expect(try form("pt-BR", "many") == "%lld páginas")
        #expect(try form("ru", "one") == "%lld страница")
        #expect(try form("ru", "few") == "%lld страницы")
        #expect(try form("ru", "many") == "%lld страниц")
        #expect(try form("ru", "other") == "%lld страниц")
        #expect(try form("zh-Hans", "other") == "%lld 页")
        #expect(try form("fr", "one") == "%lld page")
        #expect(try form("fr", "other") == "%lld pages")
        #expect(try form("fr", "many") == "%lld pages")
    }

    private static func localizableCatalogURL() -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("Beaver/Localizable.xcstrings")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    private static func primaryValue(_ localization: [String: Any]) -> String {
        if let unit = localization["stringUnit"] as? [String: Any], let value = unit["value"] as? String {
            return value
        }
        if let variations = localization["variations"] as? [String: Any],
           let plural = variations["plural"] as? [String: Any],
           let other = plural["other"] as? [String: Any],
           let unit = other["stringUnit"] as? [String: Any],
           let value = unit["value"] as? String {
            return value
        }
        return ""
    }

    private static func formatTokens(in string: String) -> [String] {
        let pattern = "%(?:\\d+\\$)?[#0-9]*\\.?\\d*[a-zA-Z@]|%#@[A-Za-z0-9_]+@|%%"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return regex.matches(in: string, range: range).compactMap { match in
            Range(match.range, in: string).map { String(string[$0]) }
        }
    }
}
