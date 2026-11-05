import BeaverCore
import SwiftUI

/// The window toolbar, read left to right as a workflow: add, arrange, then export, with
/// Create PDF as the one prominent button at the trailing end. Remove lives in the More menu
/// so the destructive action is never one stray click away.
struct WorkspaceToolbar: ToolbarContent {
    @ObservedObject var reactor: BeaverReactor
    @Binding var thumbnailSize: Double

    private var state: BeaverReactor.State { reactor.state }

    var body: some ToolbarContent {
        ToolbarItem {
            Button {
                reactor.send(.chooseFiles)
            } label: {
                Label(DesignSystem.Workspace.addFiles, systemImage: DesignSystem.Icons.addFiles)
            }
            .help(DesignSystem.Workspace.addFilesHelp)
            .disabled(!state.canEdit)
        }

        ToolbarItem {
            ControlGroup {
                rotateButton(.left)
                rotateButton(.right)
            } label: {
                Label(DesignSystem.Workspace.rotate, systemImage: DesignSystem.Icons.rotateRight)
            }
            .disabled(!state.canRotateAll)
        }

        ToolbarItem {
            Menu {
                Button(DesignSystem.Pages.selectAll) { reactor.action(.selectAll) }
                    .disabled(state.isEmpty)
                Button(DesignSystem.Commands.deselectAll) { reactor.action(.deselectAll) }
                    .disabled(!state.hasSelection)
                Divider()
                Button(DesignSystem.Workspace.remove, role: .destructive) {
                    reactor.action(.remove(state.selection.ids))
                }
                .disabled(!state.canRemoveSelection)
                Button(DesignSystem.Workspace.removeAll, role: .destructive) {
                    reactor.send(.requestRemoveAll)
                }
                .disabled(!state.canRemoveAll)
            } label: {
                Label(DesignSystem.Workspace.more, systemImage: DesignSystem.Icons.more)
            }
            .help(DesignSystem.Workspace.more)
            .disabled(state.isEmpty)
        }

        ToolbarItem {
            HStack(spacing: 4) {
                Image(systemName: DesignSystem.Icons.thumbnailSmall)
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Slider(
                    value: $thumbnailSize,
                    in: DesignSystem.Layout.thumbnailSizeRange,
                    step: DesignSystem.Layout.thumbnailSizeStep
                )
                .frame(width: 110)
                .controlSize(.small)
                .accessibilityLabel(DesignSystem.Workspace.thumbnailSize)
                Image(systemName: DesignSystem.Icons.thumbnailLarge)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.secondary)
            .help(DesignSystem.Workspace.thumbnailSize)
            .disabled(state.isEmpty)
        }

        ToolbarItem {
            Button {
                reactor.send(.splitIntoPages)
            } label: {
                Label(DesignSystem.Workspace.splitIntoPages, systemImage: DesignSystem.Icons.splitIntoPages)
            }
            .help(DesignSystem.Workspace.splitHelp(selection: state.hasSelection))
            .disabled(!state.canExport)
        }

        ToolbarItem {
            Button {
                reactor.send(.createPDF)
            } label: {
                Label(DesignSystem.Workspace.createPDF, systemImage: DesignSystem.Icons.createPDF)
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .help(DesignSystem.Workspace.createPDFHelp(state.exportKind, selection: state.hasSelection))
            .disabled(!state.canExport)
        }
    }

    private func rotateButton(_ direction: RotationDirection) -> some View {
        Button {
            reactor.action(.rotateAll(direction))
        } label: {
            Label(
                direction == .left ? DesignSystem.Workspace.rotateLeft : DesignSystem.Workspace.rotateRight,
                systemImage: direction == .left ? DesignSystem.Icons.rotateLeft : DesignSystem.Icons.rotateRight
            )
        }
        .help(DesignSystem.Workspace.rotateHelp(direction, selection: state.hasSelection))
    }
}
