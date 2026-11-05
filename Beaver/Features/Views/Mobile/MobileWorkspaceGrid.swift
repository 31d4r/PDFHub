#if os(iOS)
import BeaverCore
import SwiftUI

/// The files as cards, as many columns as fit (fewer with larger text). A tap opens a file,
/// or chooses it while selecting; touch and hold for the context menu or to drag it to a new
/// place in the order.
struct MobileWorkspaceGrid: View {
    let isSelecting: Bool

    @EnvironmentObject private var reactor: BeaverReactor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var minimumCardWidth = DesignSystem.Mobile.minimumCardWidth

    private var items: [WorkspaceItem] { reactor.state.items }

    var body: some View {
        GeometryReader { geometry in
            let layout = layout(for: geometry.size.width)
            ScrollView {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: DesignSystem.Mobile.gridSpacing, alignment: .top),
                        count: layout.columns
                    ),
                    spacing: DesignSystem.Mobile.gridSpacing
                ) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        card(item, index: index, size: layout.thumbnail)
                    }
                }
                .padding(DesignSystem.Mobile.contentPadding)
            }
            .accessibilityLabel(DesignSystem.Accessibility.fileList)
        }
    }

    private func card(_ item: WorkspaceItem, index: Int, size: CGFloat) -> some View {
        let isSelected = reactor.state.selection.contains(item.id)
        let cardActions = WorkspaceCardActions(reactor: reactor, item: item, isSelected: isSelected)
        return ItemCardView(
            item: item,
            size: size,
            isSelected: isSelecting && isSelected,
            showsFocus: false,
            isEnabled: reactor.state.canEdit,
            onRotate: { direction in reactor.action(.rotate(id: item.id, direction: direction)) },
            onShowPages: { reactor.action(.showPages(id: item.id)) }
        )
        .overlay(alignment: .topTrailing) {
            if isSelecting {
                SelectionBadge(isSelected: isSelected)
                    .padding(Constants.badgeInset)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onTapGesture { tap(item) }
        .accessibilityAction(.default) { tap(item) }
        .reorderableCard(
            id: item.id,
            index: index,
            count: items.count,
            title: item.name,
            systemImage: item.kind == .pdf ? DesignSystem.Icons.pdf : DesignSystem.Icons.image,
            cornerRadius: DesignSystem.Layout.selectionRadius,
            isEnabled: reactor.state.canEdit,
            actions: cardActions.leading,
            trailingActions: cardActions.trailing,
            onMove: { id, destination in reactor.action(.move(id: id, to: destination)) }
        )
        .sensoryFeedback(.selection, trigger: isSelected)
        .animation(reduceMotion ? nil : .snappy(duration: Constants.badgeDuration), value: isSelecting)
    }

    private func tap(_ item: WorkspaceItem) {
        if isSelecting {
            reactor.action(.select(item.id, .command))
        } else {
            reactor.action(.open(id: item.id))
        }
    }

    /// Columns at least `minimumCardWidth` wide, and the thumbnail edge that fills one.
    private func layout(for width: CGFloat) -> (columns: Int, thumbnail: CGFloat) {
        let available = max(width - 2 * DesignSystem.Mobile.contentPadding, minimumCardWidth)
        let columns = max(1, GridLayout.columnCount(
            width: available,
            minimum: minimumCardWidth,
            spacing: DesignSystem.Mobile.gridSpacing
        ))
        let cell = (available - CGFloat(columns - 1) * DesignSystem.Mobile.gridSpacing) / CGFloat(columns)
        return (columns, max(floor(cell - 2 * Constants.cardHighlightPadding), Constants.minimumThumbnail))
    }
}

/// The round check in a card's corner while selecting, as in Photos.
private struct SelectionBadge: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? DesignSystem.Icons.selectedPage : DesignSystem.Icons.selectionEmpty)
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.white, isSelected ? Color.accentColor : Color.black.opacity(0.25))
            .font(.title2)
            .background(Circle().fill(.ultraThinMaterial).opacity(isSelected ? 0 : 1))
            .shadow(color: .black.opacity(0.2), radius: 2)
            .accessibilityHidden(true)
    }
}

private enum Constants {
    /// Matches `ItemCardView`'s highlight padding.
    static let cardHighlightPadding: CGFloat = 8
    static let minimumThumbnail: CGFloat = 80
    static let badgeInset: CGFloat = 12
    static let badgeDuration: Double = 0.2
}
#endif
