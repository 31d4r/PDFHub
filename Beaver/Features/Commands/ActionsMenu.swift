import BeaverCore
import SwiftUI

/// The menu bar's Actions menu as data, so its titles, shortcuts and enabled states can be
/// tested without a menu bar. `BeaverCommands` draws it and `perform(_:on:)` runs an item.
enum ActionsMenu {
    enum Command: CaseIterable, Sendable {
        case addFiles
        case merge, split, convert, combine
        case exportPNG, exportJPEG
        case rotateLeft, rotateRight, rotateAllLeft, rotateAllRight
        case showPages, quickLook
        case remove, removeAll
    }

    struct Item: Identifiable {
        let command: Command
        let title: String
        let key: KeyEquivalent
        let modifiers: EventModifiers
        let isEnabled: Bool
        /// Draw a separator above this item.
        let startsGroup: Bool

        var id: Command { command }
    }

    static func items(for state: BeaverReactor.State?) -> [Item] {
        Command.allCases.map { item($0, state: state) }
    }

    static func item(_ command: Command, state: BeaverReactor.State?) -> Item {
        Item(
            command: command,
            title: title(command),
            key: shortcut(command).key,
            modifiers: shortcut(command).modifiers,
            isEnabled: state.map { isEnabled(command, in: $0) } ?? false,
            startsGroup: [.merge, .exportPNG, .rotateLeft, .showPages, .remove].contains(command)
        )
    }

    static func title(_ command: Command) -> String {
        switch command {
        case .addFiles: return DesignSystem.Commands.addFiles
        case .merge: return DesignSystem.Actions.menuTitle(.merge)
        case .split: return DesignSystem.Actions.menuTitle(.split)
        case .convert: return DesignSystem.Actions.menuTitle(.convert)
        case .combine: return DesignSystem.Actions.menuTitle(.combine)
        case .exportPNG: return DesignSystem.Actions.menuTitle(.exportPNG)
        case .exportJPEG: return DesignSystem.Actions.menuTitle(.exportJPEG)
        case .rotateLeft: return DesignSystem.Commands.rotateLeft
        case .rotateRight: return DesignSystem.Commands.rotateRight
        case .rotateAllLeft: return DesignSystem.Commands.rotateAllLeft
        case .rotateAllRight: return DesignSystem.Commands.rotateAllRight
        case .showPages: return DesignSystem.Commands.showPages
        case .quickLook: return DesignSystem.Commands.quickLook
        case .remove: return DesignSystem.Commands.remove
        case .removeAll: return DesignSystem.Commands.removeAll
        }
    }

    static func shortcut(_ command: Command) -> (key: KeyEquivalent, modifiers: EventModifiers) {
        switch command {
        case .addFiles: return ("o", .command)
        case .merge: return ("m", [.command, .option])
        case .split: return ("s", [.command, .option])
        case .convert: return ("i", [.command, .option])
        case .combine: return ("c", [.command, .option])
        case .exportPNG: return ("e", [.command, .option])
        case .exportJPEG: return ("e", [.command, .option, .shift])
        case .rotateLeft: return ("l", .command)
        case .rotateRight: return ("r", .command)
        case .rotateAllLeft: return ("l", [.command, .shift])
        case .rotateAllRight: return ("r", [.command, .shift])
        case .showPages: return ("p", [.command, .option])
        case .quickLook: return ("y", .command)
        case .remove: return (.delete, .command)
        case .removeAll: return (.delete, [.command, .shift])
        }
    }

    /// The shortcut as the menu bar draws it, "⇧⌘L", to match the tooltips and the Keyboard
    /// Shortcuts window.
    static func displayShortcut(_ command: Command) -> String {
        let (key, modifiers) = shortcut(command)
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        text += key == .delete ? "⌫" : String(key.character).uppercased()
        return text
    }

    static func documentAction(_ command: Command) -> DocumentAction? {
        switch command {
        case .merge: return .merge
        case .split: return .split
        case .convert: return .convert
        case .combine: return .combine
        case .exportPNG: return .exportPNG
        case .exportJPEG: return .exportJPEG
        default: return nil
        }
    }

    static func isEnabled(_ command: Command, in state: BeaverReactor.State) -> Bool {
        if let action = documentAction(command) {
            return state.availability(of: action).isAvailable
        }
        switch command {
        case .addFiles: return state.canEdit
        case .rotateLeft, .rotateRight: return state.canRotateSelection
        case .rotateAllLeft, .rotateAllRight: return state.canRotateAll
        case .showPages: return state.canEdit && state.showPagesTarget != nil
        case .quickLook: return !state.isEmpty
        case .remove: return state.canRemoveSelection
        case .removeAll: return state.canRemoveAll
        case .merge, .split, .convert, .combine, .exportPNG, .exportJPEG: return false
        }
    }

    @MainActor
    static func perform(_ command: Command, on reactor: BeaverReactor) {
        if let action = documentAction(command) {
            reactor.send(.perform(action))
            return
        }
        switch command {
        case .addFiles: reactor.send(.chooseFiles)
        case .rotateLeft: reactor.action(.rotateSelection(.left))
        case .rotateRight: reactor.action(.rotateSelection(.right))
        case .rotateAllLeft: reactor.action(.rotateAll(.left))
        case .rotateAllRight: reactor.action(.rotateAll(.right))
        case .showPages:
            if let pdf = reactor.state.showPagesTarget { reactor.action(.showPages(id: pdf.id)) }
        case .quickLook: reactor.action(.toggleQuickLook)
        case .remove: reactor.action(.remove(reactor.state.selection.ids))
        case .removeAll: reactor.send(.requestRemoveAll)
        case .merge, .split, .convert, .combine, .exportPNG, .exportJPEG: break
        }
    }
}

extension BeaverReactor.State {
    /// The PDF Show Pages opens: the focused file if it's a PDF, else the only selected PDF.
    var showPagesTarget: PDFItem? {
        if let focus = selection.focus, let pdf = items.first(where: { $0.id == focus })?.pdf {
            return pdf
        }
        let selected = selectedItems.compactMap(\.pdf)
        return selected.count == 1 ? selected.first : nil
    }
}
