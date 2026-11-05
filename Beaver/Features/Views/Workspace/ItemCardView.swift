import BeaverCore
import SwiftUI

/// One file in the grid, Finder style: the thumbnail on a rounded highlight when selected,
/// then the name (on an accent capsule when selected) and a line of details.
struct ItemCardView: View {
    let item: WorkspaceItem
    let size: CGFloat
    let isSelected: Bool
    /// Keyboard focus that isn't selected, after ⌘-clicking the focused file off.
    let showsFocus: Bool
    let isEnabled: Bool
    let onRotate: (RotationDirection) -> Void
    let onShowPages: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovering = false
    @State private var pageCount: Int?

    var body: some View {
        VStack(spacing: Constants.labelSpacing) {
            ItemThumbnail(item: item) { pageCount = $0 }
                .frame(width: size, height: size)
                .overlay(alignment: .topTrailing) { badge }
                .padding(Constants.highlightPadding)
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.selectionRadius, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.selectionRadius, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(ringOpacity), lineWidth: Constants.ringWidth)
                }
                .overlay(alignment: .bottom) {
                    if isHovering && isEnabled {
                        RotateControlsView(
                            subject: item.name,
                            extra: item.kind == .pdf ? showPagesAction : nil,
                            onRotate: onRotate
                        )
                        .padding(.bottom, Constants.controlsInset)
                        .transition(.opacity)
                    }
                }

            VStack(spacing: Constants.metaSpacing) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .padding(.horizontal, Constants.namePadding)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: Constants.nameRadius, style: .continuous)
                                .fill(Color.accentColor)
                        }
                    }
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: size + 2 * Constants.highlightPadding)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: Constants.hoverDuration)) { isHovering = hovering }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DesignSystem.Card.accessibilityLabel(
            name: item.name,
            meta: meta,
            rotation: ItemThumbnail.angle(of: item)
        ))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var ringOpacity: Double {
        if isSelected { return contrast == .increased ? 1 : 0 }
        return showsFocus ? 0.6 : 0
    }

    private var meta: String {
        switch item {
        case .pdf:
            return DesignSystem.Card.pdfMeta(pageCount: pageCount)
        case .image(let image):
            return DesignSystem.Card.imageMeta(fileExtension: image.url.pathExtension, pixelSize: image.pixelSize)
        }
    }

    private var showPagesAction: CardAction {
        CardAction(
            title: DesignSystem.Pages.showPages,
            systemImage: DesignSystem.Icons.pages,
            help: DesignSystem.Help.showPages,
            perform: onShowPages
        )
    }

    @ViewBuilder
    private var badge: some View {
        if let pdf = item.pdf, pdf.hasPageRotations {
            Image(systemName: DesignSystem.Icons.pagesRotated)
                .font(.caption)
                .foregroundStyle(.white)
                .padding(Constants.badgePadding)
                .background(Color.accentColor, in: Circle())
                .help(DesignSystem.Help.pagesRotatedBadge)
                .accessibilityLabel(DesignSystem.Card.pagesRotatedBadge)
                .offset(x: Constants.badgeOffset, y: -Constants.badgeOffset)
        }
    }
}

private enum Constants {
    static let labelSpacing: CGFloat = 4
    static let metaSpacing: CGFloat = 2
    static let highlightPadding: CGFloat = 8
    static let ringWidth: CGFloat = 2
    static let controlsInset: CGFloat = 6
    static let namePadding: CGFloat = 5
    static let nameRadius: CGFloat = 4
    static let hoverDuration: Double = 0.12
    static let badgePadding: CGFloat = 4
    static let badgeOffset: CGFloat = 4
}
