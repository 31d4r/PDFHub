import BeaverCore
import SwiftUI

/// The commands a workspace card offers in its context menu and to VoiceOver, shared by the
/// Mac and iOS grids. Like Finder, they apply to the whole selection when the card is part of
/// it, and to that card alone otherwise.
@MainActor
struct WorkspaceCardActions {
    let reactor: BeaverReactor
    let item: WorkspaceItem
    let isSelected: Bool

    private var state: BeaverReactor.State { reactor.state }
    private var isEnabled: Bool { state.canEdit }

    /// The files the commands work on.
    var targets: Set<UUID> { isSelected ? state.selection.ids : [item.id] }

    /// Show Pages, Quick Look, Rotate, then Merge, Split, Convert and Combine where they apply.
    var leading: [CardAction] {
        var actions: [CardAction] = []
        if item.kind == .pdf {
            actions.append(CardAction(
                title: DesignSystem.Pages.showPages,
                systemImage: DesignSystem.Icons.pages,
                isEnabled: isEnabled,
                help: DesignSystem.Help.showPages
            ) { reactor.action(.showPages(id: item.id)) })
        }
        actions.append(CardAction(
            title: DesignSystem.Workspace.quickLook,
            systemImage: DesignSystem.Icons.quickLook,
            help: DesignSystem.Help.quickLook
        ) {
            reactor.action(.didChangeQuickLook(item.url))
        })
        actions.append(CardAction(
            title: DesignSystem.Scan.recognizedText,
            systemImage: "text.viewfinder",
            help: DesignSystem.Scan.recognizedTextHelp
        ) {
            Task { await reactor.action(.recognizeText(id: item.id)) }
        })
        for direction in [RotationDirection.left, .right] {
            actions.append(CardAction(
                title: direction == .left ? DesignSystem.Workspace.rotateLeft : DesignSystem.Workspace.rotateRight,
                systemImage: direction == .left ? DesignSystem.Icons.rotateLeft : DesignSystem.Icons.rotateRight,
                isEnabled: isEnabled,
                help: DesignSystem.Help.rotate(direction)
            ) {
                if isSelected && reactor.state.selection.count > 1 {
                    reactor.action(.rotateSelection(direction))
                } else {
                    reactor.action(.rotate(id: item.id, direction: direction))
                }
            })
        }
        let targets = targets
        let available = DocumentAction.allCases.filter {
            state.availability(of: $0, ids: targets).isAvailable
        }
        for (index, action) in available.enumerated() {
            actions.append(CardAction(
                title: DesignSystem.Actions.menuTitle(action),
                systemImage: DesignSystem.Actions.icon(action),
                help: DesignSystem.Help.action(action, state.availability(of: action, ids: targets)),
                startsGroup: index == 0
            ) {
                reactor.send(.perform(action, ids: targets))
            })
        }
        return actions
    }

    /// Remove, after the move items.
    var trailing: [CardAction] {
        let targets = targets
        return [
            CardAction(
                title: DesignSystem.Workspace.remove,
                systemImage: DesignSystem.Icons.remove,
                role: .destructive,
                isEnabled: isEnabled,
                help: DesignSystem.Help.remove
            ) {
                reactor.action(.remove(targets))
            }
        ]
    }
}
