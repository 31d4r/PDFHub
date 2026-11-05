import BeaverCore
import SwiftUI

/// The window toolbar, read left to right as a workflow: add and arrange, then the actions that
/// make PDFs, each named for exactly what it does. Every button carries its title, works on the
/// selection (or everything when nothing is selected), and explains itself when it's dimmed.
/// Remove lives in the More menu so the destructive action is never one stray click away.
struct WorkspaceToolbar: ToolbarContent {
    @ObservedObject var reactor: BeaverReactor

    private var state: BeaverReactor.State { reactor.state }

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                reactor.send(.chooseFiles)
            } label: {
                Label(DesignSystem.Workspace.addFiles, systemImage: DesignSystem.Icons.addFiles)
                    .labelStyle(.titleAndIcon)
            }
            .help(DesignSystem.Help.addFiles)
            .disabled(!state.canEdit)
        }

        ToolbarItemGroup {
            rotateMenu
            moreMenu
        }

        ToolbarItemGroup(placement: .primaryAction) {
            actionButton(.merge)
            actionButton(.split)
            actionButton(.convert)
            if state.hasBothKinds {
                actionButton(.combine)
            }
        }
    }

    /// Says up front whether it turns the selection or everything; the items that can't
    /// apply (Rotate Selected with nothing selected) stay visible but dimmed.
    private var rotateMenu: some View {
        Menu {
            Section(DesignSystem.Workspace.selectedSection) {
                rotateButton(.left, selection: true)
                rotateButton(.right, selection: true)
            }
            Section(DesignSystem.Workspace.allSection) {
                rotateButton(.left, selection: false)
                rotateButton(.right, selection: false)
            }
        } label: {
            Label(DesignSystem.Workspace.rotate, systemImage: DesignSystem.Icons.rotate)
                .labelStyle(.titleAndIcon)
        }
        .help(DesignSystem.Workspace.rotateMenuHelp)
        .disabled(!state.canRotateAll)
    }

    private var moreMenu: some View {
        Menu {
            Button(DesignSystem.Pages.selectAll) { reactor.action(.selectAll) }
                .help(DesignSystem.Help.selectAll)
                .disabled(state.isEmpty)
            Button(DesignSystem.Commands.deselectAll) { reactor.action(.deselectAll) }
                .help(DesignSystem.Help.deselectAll)
                .disabled(!state.hasSelection)
            Divider()
            Button(DesignSystem.Workspace.remove, role: .destructive) {
                reactor.action(.remove(state.selection.ids))
            }
            .help(DesignSystem.Help.remove)
            .disabled(!state.canRemoveSelection)
            Button(DesignSystem.Workspace.removeAll, role: .destructive) {
                reactor.send(.requestRemoveAll)
            }
            .help(DesignSystem.Help.removeAll)
            .disabled(!state.canRemoveAll)
        } label: {
            Label(DesignSystem.Workspace.more, systemImage: DesignSystem.Icons.more)
        }
        .help(DesignSystem.Help.more)
        .disabled(state.isEmpty)
    }

    private func actionButton(_ action: DocumentAction) -> some View {
        let availability = state.availability(of: action)
        return Button {
            reactor.send(.perform(action))
        } label: {
            Label(DesignSystem.Actions.title(action), systemImage: DesignSystem.Actions.icon(action))
                .labelStyle(.titleAndIcon)
        }
        .help(DesignSystem.Help.action(action, availability))
        .disabled(!availability.isAvailable)
    }

    private func rotateButton(_ direction: RotationDirection, selection: Bool) -> some View {
        let title: String
        switch (direction, selection) {
        case (.left, true): title = DesignSystem.Workspace.rotateSelectedLeft
        case (.right, true): title = DesignSystem.Workspace.rotateSelectedRight
        case (.left, false): title = DesignSystem.Workspace.rotateAllLeft
        case (.right, false): title = DesignSystem.Workspace.rotateAllRight
        }
        return Button {
            reactor.action(selection ? .rotateSelection(direction) : .rotateAll(direction))
        } label: {
            Label(title, systemImage: direction == .left ? DesignSystem.Icons.rotateLeft : DesignSystem.Icons.rotateRight)
        }
        .help(DesignSystem.Help.rotateMenuItem(direction, selection: selection))
        .disabled(selection ? !state.canRotateSelection : !state.canRotateAll)
    }
}
