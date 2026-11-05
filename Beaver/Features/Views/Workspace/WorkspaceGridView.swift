import BeaverCore
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Every file in one grid, in output order. Click, ⌘-click and ⇧-click select; arrows move the
/// selection; Delete removes (with undo); Space is Quick Look; Return or a double-click opens.
struct WorkspaceGridView: View {
    @EnvironmentObject private var reactor: BeaverReactor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(DesignSystem.Layout.thumbnailSizeKey) private var thumbnailSize = DesignSystem.Layout.defaultThumbnailSize
    @FocusState private var isFocused: Bool
    @State private var columnCount = 1

    private var items: [WorkspaceItem] { reactor.state.items }
    private var isEnabled: Bool { reactor.state.canEdit }

    private var size: CGFloat {
        CGFloat(GridLayout.clampedSize(thumbnailSize, in: DesignSystem.Layout.thumbnailSizeRange))
    }

    private var cellWidth: CGFloat { size + 2 * Constants.highlightPadding }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    grid
                        .padding(DesignSystem.Spacing.contentPadding)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                        .background {
                            // Clicking between cards clears the selection, as in Finder.
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    isFocused = true
                                    reactor.action(.deselectAll)
                                }
                        }
                }
                .onAppear { updateColumns(width: geometry.size.width) }
                .onChange(of: geometry.size.width) { _, width in updateColumns(width: width) }
                .onChange(of: size) { _, _ in updateColumns(width: geometry.size.width) }
                .focusable()
                .focused($isFocused)
                .focusEffectDisabled()
                .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                    moveFocus(press.key, extending: press.modifiers.contains(.shift))
                    if let focus = reactor.state.selection.focus {
                        withAnimation(reduceMotion ? nil : .easeInOut) { proxy.scrollTo(focus) }
                    }
                    return .handled
                }
                .onKeyPress(.space) {
                    reactor.action(.toggleQuickLook)
                    return .handled
                }
                .onKeyPress(.return) {
                    guard let focus = reactor.state.selection.focus else { return .ignored }
                    reactor.action(.open(id: focus))
                    return .handled
                }
                .onExitCommand { reactor.action(.deselectAll) }
                .gridCommands(
                    onDelete: removeSelection,
                    onSelectAll: { reactor.action(.selectAll) }
                )
                .onAppear { isFocused = true }
                .accessibilityLabel(DesignSystem.Accessibility.fileList)
            }
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: cellWidth, maximum: cellWidth * Constants.cellStretch), spacing: DesignSystem.Spacing.gridSpacing, alignment: .top)],
            spacing: DesignSystem.Spacing.gridSpacing
        ) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                card(item, index: index)
            }
        }
    }

    private func card(_ item: WorkspaceItem, index: Int) -> some View {
        let isSelected = reactor.state.selection.contains(item.id)
        return ItemCardView(
            item: item,
            size: size,
            isSelected: isSelected,
            showsFocus: isFocused && !isSelected && reactor.state.selection.focus == item.id,
            isEnabled: isEnabled,
            onRotate: { direction in reactor.action(.rotate(id: item.id, direction: direction)) },
            onShowPages: { reactor.action(.showPages(id: item.id)) }
        )
        .onTapGesture(count: 2) {
            reactor.action(.open(id: item.id))
        }
        .simultaneousGesture(TapGesture().onEnded {
            isFocused = true
            reactor.action(.select(item.id, Self.currentModifier))
        })
        .reorderableCard(
            id: item.id,
            index: index,
            count: items.count,
            title: item.name,
            systemImage: item.kind == .pdf ? DesignSystem.Icons.pdf : DesignSystem.Icons.image,
            cornerRadius: DesignSystem.Layout.selectionRadius,
            isEnabled: isEnabled,
            actions: actions(for: item, isSelected: isSelected),
            trailingActions: [
                CardAction(
                    title: DesignSystem.Workspace.remove,
                    systemImage: DesignSystem.Icons.remove,
                    role: .destructive,
                    isEnabled: isEnabled
                ) {
                    reactor.action(.remove(contextTargets(item, isSelected: isSelected)))
                }
            ],
            onMove: { id, destination in reactor.action(.move(id: id, to: destination)) }
        )
        .id(item.id)
    }

    /// Context menu commands. Like Finder, they apply to the whole selection when the clicked
    /// file is part of it, and to that file alone otherwise.
    private func actions(for item: WorkspaceItem, isSelected: Bool) -> [CardAction] {
        var actions: [CardAction] = []
        if item.kind == .pdf {
            actions.append(CardAction(
                title: DesignSystem.Pages.showPages,
                systemImage: DesignSystem.Icons.pages,
                isEnabled: isEnabled
            ) { reactor.action(.showPages(id: item.id)) })
        }
        actions.append(CardAction(title: DesignSystem.Workspace.quickLook, systemImage: DesignSystem.Icons.quickLook) {
            reactor.action(.didChangeQuickLook(item.url))
        })
        for direction in [RotationDirection.left, .right] {
            actions.append(CardAction(
                title: direction == .left ? DesignSystem.Workspace.rotateLeft : DesignSystem.Workspace.rotateRight,
                systemImage: direction == .left ? DesignSystem.Icons.rotateLeft : DesignSystem.Icons.rotateRight,
                isEnabled: isEnabled
            ) {
                if isSelected && reactor.state.selection.count > 1 {
                    reactor.action(.rotateAll(direction))
                } else {
                    reactor.action(.rotate(id: item.id, direction: direction))
                }
            })
        }
        return actions
    }

    private func contextTargets(_ item: WorkspaceItem, isSelected: Bool) -> Set<UUID> {
        isSelected ? reactor.state.selection.ids : [item.id]
    }

    private func removeSelection() {
        guard reactor.state.canRemoveSelection else { return }
        withAnimation(reduceMotion ? nil : .snappy) {
            reactor.action(.remove(reactor.state.selection.ids))
        }
    }

    private func moveFocus(_ key: KeyEquivalent, extending: Bool) {
        let offset: Int
        switch key {
        case .leftArrow: offset = -1
        case .rightArrow: offset = 1
        case .upArrow: offset = -columnCount
        default: offset = columnCount
        }
        reactor.action(.moveFocus(offset: offset, extending: extending))
    }

    private func updateColumns(width: CGFloat) {
        columnCount = GridLayout.columnCount(
            width: width - 2 * DesignSystem.Spacing.contentPadding,
            minimum: cellWidth,
            spacing: DesignSystem.Spacing.gridSpacing
        )
    }

    private static var currentModifier: BeaverReactor.SelectionModifier {
        #if os(macOS)
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) { return .shift }
        if flags.contains(.command) { return .command }
        return .none
        #else
        return .command
        #endif
    }
}

private extension View {
    /// Delete and Edit > Select All while the grid has focus, on the Mac.
    @ViewBuilder
    func gridCommands(onDelete: @escaping () -> Void, onSelectAll: @escaping () -> Void) -> some View {
        #if os(macOS)
        self
            .onDeleteCommand(perform: onDelete)
            .onCommand(#selector(NSResponder.selectAll(_:)), perform: onSelectAll)
        #else
        self
        #endif
    }
}

private enum Constants {
    /// Matches the card's highlight padding.
    static let highlightPadding: CGFloat = 8
    /// How far a column may widen to spread cards across the row.
    static let cellStretch: CGFloat = 1.6
}
