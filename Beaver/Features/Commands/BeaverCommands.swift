import SwiftUI

/// Menu bar commands for the focused window. Each one sends the same reactor
/// action as the matching on-screen button, so confirmations and guards apply.
struct BeaverCommands: Commands {
    @FocusedObject private var reactor: BeaverReactor?

    var body: some Commands {
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

    private var canConvertImages: Bool {
        isIdle && reactor?.state.screen == .imageWorkflow && !(reactor?.state.selectedImages.isEmpty ?? true)
    }
}
