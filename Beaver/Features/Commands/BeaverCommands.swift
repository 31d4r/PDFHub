import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Menu bar commands for the focused window. Each one sends the same reactor
/// action as the matching on-screen button, so confirmations and guards apply.
struct BeaverCommands: Commands {
    @FocusedObject private var reactor: BeaverReactor?

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(undoTitle) {
                if let reactor, reactor.state.rotationHistory.canUndo {
                    reactor.action(.undo)
                } else {
                    sendToResponderChain("undo:")
                }
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(isRotationHistoryBlocked)

            Button(redoTitle) {
                if let reactor, reactor.state.rotationHistory.canRedo {
                    reactor.action(.redo)
                } else {
                    sendToResponderChain("redo:")
                }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(isRotationHistoryBlocked)
        }

        CommandGroup(after: .newItem) {
            Button(DesignSystem.Commands.addPDFs) {
                reactor?.send(.selectPDF)
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(!isIdle)

            Button(DesignSystem.Commands.addImages) {
                reactor?.send(.selectImages)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(!isIdle)
        }

        CommandMenu(DesignSystem.Commands.menuTitle) {
            Button(DesignSystem.Commands.mergePDFs) {
                guard let reactor else { return }
                reactor.send(.mergePDF(reactor.state.selectedPDFs.map(\.url)))
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
            .disabled(!canExportPDFs)

            Button(DesignSystem.Commands.splitPDFs) {
                guard let reactor else { return }
                reactor.send(.splitPDF(reactor.state.selectedPDFs.map(\.url)))
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(!canExportPDFs)

            Button(DesignSystem.Commands.convertToPDF) {
                reactor?.send(.convertImagesToPDF)
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
            .disabled(!canConvertImages)

            Divider()

            Button(DesignSystem.Commands.rotateAllLeft) {
                reactor?.action(.rotateAll(.left))
            }
            .keyboardShortcut("l", modifiers: .command)
            .disabled(!canRotateAll)

            Button(DesignSystem.Commands.rotateAllRight) {
                reactor?.action(.rotateAll(.right))
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(!canRotateAll)

            Divider()

            Button(DesignSystem.Commands.back) {
                reactor?.send(.requestDiscard(.goBack))
            }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(!isIdle || reactor?.state.screen == .menu)

            Button(DesignSystem.Commands.clearAll) {
                reactor?.send(.requestDiscard(.clearAll))
            }
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(!isIdle || (reactor?.state.discardableCount ?? 0) == 0)
        }
    }

    private var isIdle: Bool {
        guard let reactor else { return false }
        return reactor.state.activity == nil && reactor.state.pendingDiscard == nil
    }

    private var canExportPDFs: Bool {
        isIdle && reactor?.state.screen == .pdfWorkflow && !(reactor?.state.selectedPDFs.isEmpty ?? true)
    }

    private var canRotateAll: Bool {
        isIdle && (reactor?.state.canRotateAll ?? false)
    }

    private var undoTitle: String {
        guard let label = reactor?.state.rotationHistory.undoLabel else { return DesignSystem.Commands.undo }
        return DesignSystem.Commands.undo(label.title)
    }

    private var redoTitle: String {
        guard let label = reactor?.state.rotationHistory.redoLabel else { return DesignSystem.Commands.redo }
        return DesignSystem.Commands.redo(label.title)
    }

    /// Rotations can't be undone mid-export. Otherwise the items stay enabled so text fields
    /// (such as a save panel's name field) still get Undo and Redo through the responder chain.
    private var isRotationHistoryBlocked: Bool {
        reactor?.state.activity != nil
    }

    /// Hands Undo or Redo to the first responder, as the standard Edit menu would.
    private func sendToResponderChain(_ selector: String) {
        #if os(macOS)
        NSApp.sendAction(Selector((selector)), to: nil, from: nil)
        #endif
    }

    private var canConvertImages: Bool {
        isIdle && reactor?.state.screen == .imageWorkflow && !(reactor?.state.selectedImages.isEmpty ?? true)
    }
}
