import BeaverCore
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Menu bar commands for the focused window. Each one sends the same reactor action as the
/// matching toolbar button, so every toolbar action is also in the menu bar with a shortcut.
/// The Actions menu's items come from `ActionsMenu`.
struct BeaverCommands: Commands {
    @FocusedObject private var reactor: BeaverReactor?
    @AppStorage(TextSearchablePreference.key) private var makeTextSearchable = true
    #if os(macOS)
    @AppStorage(DesignSystem.Layout.thumbnailSizeKey) private var thumbnailSize = DesignSystem.Layout.defaultThumbnailSize
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some Commands {
        #if os(macOS)
        // There's no Help Book, so replace the item that would only say "Help isn't available"
        // with a shortcut reference that opens when asked for.
        CommandGroup(replacing: .help) {
            Button(DesignSystem.Shortcuts.menuItem) {
                openWindow(id: DesignSystem.Shortcuts.windowID)
            }
            .keyboardShortcut("/", modifiers: .command)
        }
        #endif

        CommandGroup(replacing: .undoRedo) {
            Button(undoTitle) {
                if let reactor, reactor.state.canUndo {
                    reactor.action(.undo)
                } else {
                    sendToResponderChain("undo:")
                }
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(isHistoryBlocked)

            Button(redoTitle) {
                if let reactor, reactor.state.canRedo {
                    reactor.action(.redo)
                } else {
                    sendToResponderChain("redo:")
                }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(isHistoryBlocked)
        }

        CommandGroup(after: .pasteboard) {
            Button(DesignSystem.Commands.deselectAll) {
                reactor?.action(.deselectAll)
            }
            .keyboardShortcut("a", modifiers: [.command, .option])
            .disabled(!(reactor?.state.hasSelection ?? false))
        }

        #if os(macOS)
        // The iOS grid sizes its cards to the screen instead.
        CommandGroup(after: .toolbar) {
            Button(DesignSystem.Commands.largerThumbnails) {
                resizeThumbnails(by: DesignSystem.Layout.thumbnailSizeStep)
            }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(thumbnailSize >= DesignSystem.Layout.thumbnailSizeRange.upperBound)

            Button(DesignSystem.Commands.smallerThumbnails) {
                resizeThumbnails(by: -DesignSystem.Layout.thumbnailSizeStep)
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(thumbnailSize <= DesignSystem.Layout.thumbnailSizeRange.lowerBound)

            Divider()
        }
        #endif

        CommandMenu(DesignSystem.Commands.menuTitle) {
            ForEach(ActionsMenu.items(for: reactor?.state)) { item in
                if item.startsGroup { Divider() }
                Button(item.title) {
                    guard let reactor else { return }
                    ActionsMenu.perform(item.command, on: reactor)
                }
                .keyboardShortcut(item.key, modifiers: item.modifiers)
                .disabled(!item.isEnabled)
            }
        }
    }

    #if os(macOS)
    private func resizeThumbnails(by step: Double) {
        thumbnailSize = GridLayout.clampedSize(
            thumbnailSize + step,
            step: DesignSystem.Layout.thumbnailSizeStep,
            in: DesignSystem.Layout.thumbnailSizeRange
        )
    }
    #endif

    private var undoTitle: String {
        guard let label = reactor?.state.history.undoLabel else { return DesignSystem.Commands.undo }
        return DesignSystem.Commands.undo(label.title)
    }

    private var redoTitle: String {
        guard let label = reactor?.state.history.redoLabel else { return DesignSystem.Commands.redo }
        return DesignSystem.Commands.redo(label.title)
    }

    /// Edits can't be undone mid-export. Otherwise the items stay enabled so text fields
    /// (such as a save panel's name field) still get Undo and Redo through the responder chain.
    private var isHistoryBlocked: Bool {
        reactor?.state.activity != nil
    }

    /// Hands Undo or Redo to the first responder, as the standard Edit menu would.
    private func sendToResponderChain(_ selector: String) {
        #if os(macOS)
        NSApp.sendAction(Selector((selector)), to: nil, from: nil)
        #endif
    }
}
