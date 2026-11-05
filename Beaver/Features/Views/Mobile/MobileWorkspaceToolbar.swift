#if os(iOS)
import BeaverCore
import SwiftUI

/// The iOS toolbar. Browsing: Select at the top, Add and Actions at the bottom. Selecting:
/// Select All and Done at the top, and Rotate, Actions and Remove for the chosen files at
/// the bottom. Merge, Split, Convert and Combine stay listed when they can't run and say why.
struct MobileWorkspaceToolbar: ToolbarContent {
    @ObservedObject var reactor: BeaverReactor
    @Binding var isSelecting: Bool
    let onAddPhotos: () -> Void
    let onAddFiles: () -> Void

    private var state: BeaverReactor.State { reactor.state }

    var body: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .topBarLeading) {
                selectAllButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(DesignSystem.Mobile.done) { isSelecting = false }
                    .fontWeight(.semibold)
            }
            ToolbarItemGroup(placement: .bottomBar) {
                rotateMenu
                Spacer()
                actionsMenu
                Spacer()
                removeButton
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                moreMenu
                if !state.isEmpty {
                    Button(DesignSystem.Mobile.select) { isSelecting = true }
                        .accessibilityHint(DesignSystem.Mobile.selectHelp)
                        .disabled(!state.canEdit)
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                addControl
                Spacer()
                if !state.isEmpty {
                    actionsMenu
                }
            }
        }
    }

    // MARK: - Browsing

    private var addControl: some View {
        Menu {
            Button(action: onAddPhotos) {
                Label(DesignSystem.Mobile.photos, systemImage: DesignSystem.Icons.photos)
            }
            Button(action: onAddFiles) {
                Label(DesignSystem.Mobile.browseFiles, systemImage: DesignSystem.Icons.folder)
            }
        } label: {
            Label(DesignSystem.Mobile.add, systemImage: DesignSystem.Icons.addFiles)
                .labelStyle(.titleAndIcon)
        }
        .accessibilityHint(DesignSystem.Mobile.addHelp)
        .disabled(!state.canEdit)
    }

    /// Undo and Redo, which the Mac keeps in the Edit menu, and Remove All.
    private var moreMenu: some View {
        Menu {
            Button {
                reactor.action(.undo)
            } label: {
                Label(undoTitle, systemImage: DesignSystem.Icons.undo)
            }
            .disabled(!state.canUndo)
            Button {
                reactor.action(.redo)
            } label: {
                Label(redoTitle, systemImage: DesignSystem.Icons.redo)
            }
            .disabled(!state.canRedo)
            Divider()
            Button(role: .destructive) {
                reactor.send(.requestRemoveAll)
            } label: {
                Label(DesignSystem.Workspace.removeAll, systemImage: DesignSystem.Icons.remove)
            }
            .disabled(!state.canRemoveAll)
        } label: {
            Label(DesignSystem.Workspace.more, systemImage: DesignSystem.Icons.more)
        }
        .disabled(!state.canUndo && !state.canRedo && !state.canRemoveAll)
    }

    private var undoTitle: String {
        guard let label = state.history.undoLabel else { return DesignSystem.Commands.undo }
        return DesignSystem.Commands.undo(label.title)
    }

    private var redoTitle: String {
        guard let label = state.history.redoLabel else { return DesignSystem.Commands.redo }
        return DesignSystem.Commands.redo(label.title)
    }

    // MARK: - Both

    /// Each action with a second line: what it will do, or why it can't yet.
    private var actionsMenu: some View {
        Menu {
            ForEach(DocumentAction.allCases, id: \.self) { action in
                let availability = state.availability(of: action)
                Button {
                    reactor.send(.perform(action))
                } label: {
                    Label {
                        Text(DesignSystem.Actions.title(action))
                        Text(Self.detail(availability, for: action))
                    } icon: {
                        Image(systemName: DesignSystem.Actions.icon(action))
                    }
                }
                .disabled(!availability.isAvailable)
            }
        } label: {
            Label(DesignSystem.Mobile.actions, systemImage: DesignSystem.Icons.actions)
                .labelStyle(.titleAndIcon)
        }
        .accessibilityHint(DesignSystem.Mobile.actionsHelp)
        .disabled(state.isEmpty || state.activity != nil)
    }

    static func detail(_ availability: DocumentAction.Availability, for action: DocumentAction) -> String {
        switch availability {
        case .available(let count, let selection):
            return DesignSystem.Actions.detail(action, count: count, selection: selection)
        case .unavailable(let reason):
            return DesignSystem.Actions.reason(reason)
        }
    }

    // MARK: - Selecting

    private var selectAllButton: some View {
        let allSelected = !state.isEmpty && state.selection.count == state.items.count
        return Button(allSelected ? DesignSystem.Commands.deselectAll : DesignSystem.Pages.selectAll) {
            reactor.action(allSelected ? .deselectAll : .selectAll)
        }
    }

    private var rotateMenu: some View {
        Menu {
            Button {
                reactor.action(.rotateSelection(.left))
            } label: {
                Label(DesignSystem.Workspace.rotateLeft, systemImage: DesignSystem.Icons.rotateLeft)
            }
            Button {
                reactor.action(.rotateSelection(.right))
            } label: {
                Label(DesignSystem.Workspace.rotateRight, systemImage: DesignSystem.Icons.rotateRight)
            }
        } label: {
            Label(DesignSystem.Workspace.rotate, systemImage: DesignSystem.Icons.rotate)
        }
        .disabled(!state.canRotateSelection)
    }

    private var removeButton: some View {
        Button(role: .destructive) {
            reactor.action(.remove(state.selection.ids))
        } label: {
            Label(DesignSystem.Workspace.remove, systemImage: DesignSystem.Icons.remove)
        }
        .disabled(!state.canRemoveSelection)
    }
}
#endif
