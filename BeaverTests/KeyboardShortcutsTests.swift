import Foundation
import Testing
@testable import Beaver

/// The Help ▸ Keyboard Shortcuts reference must stay in step with the real shortcuts.
struct KeyboardShortcutsTests {
    private var entries: [DesignSystem.Shortcuts.Entry] {
        DesignSystem.Shortcuts.sections.flatMap(\.entries)
    }

    @Test func everySectionHasEntries() {
        let sections = DesignSystem.Shortcuts.sections
        #expect(sections.map(\.title) == ["Files", "Arrange", "Select", "View"])
        #expect(sections.allSatisfy { !$0.entries.isEmpty })
    }

    @Test func entriesAreUnique() {
        let ids = entries.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test(arguments: [
        DesignSystem.Help.Shortcut.addFiles, DesignSystem.Help.Shortcut.createPDF,
        DesignSystem.Help.Shortcut.splitIntoPages, DesignSystem.Help.Shortcut.rotateLeft,
        DesignSystem.Help.Shortcut.rotateRight, DesignSystem.Help.Shortcut.showPages,
        DesignSystem.Help.Shortcut.quickLook, DesignSystem.Help.Shortcut.remove,
        DesignSystem.Help.Shortcut.removeAll, DesignSystem.Help.Shortcut.selectAll,
        DesignSystem.Help.Shortcut.deselectAll, DesignSystem.Help.Shortcut.larger,
        DesignSystem.Help.Shortcut.smaller, DesignSystem.Help.Shortcut.cancel,
    ])
    func everyTooltipShortcutIsListed(_ shortcut: String) {
        #expect(entries.contains { $0.keys.contains(shortcut) }, "\(shortcut) is missing from the reference")
    }

    @Test func entriesUseTheControlNames() {
        let titles = Set(entries.map(\.title))
        #expect(titles.contains(DesignSystem.Workspace.createPDF))
        #expect(titles.contains(DesignSystem.Workspace.rotateLeft))
        #expect(titles.contains(DesignSystem.Pages.showPages))
        #expect(titles.contains(DesignSystem.Commands.undo))
    }

    @Test(arguments: [
        "shortcuts.title", "shortcuts.menuItem", "shortcuts.section.files", "shortcuts.section.arrange",
        "shortcuts.section.select", "shortcuts.section.view", "shortcuts.reorder",
        "shortcuts.moveSelection", "shortcuts.extendSelection",
    ])
    func referenceKeyIsInTheCatalog(_ key: String) {
        let missing = "\u{1}missing"
        let value = Bundle.main.localizedString(forKey: key, value: missing, table: "Localizable")
        #expect(value != missing, "\(key) is not in Localizable.xcstrings")
    }
}
