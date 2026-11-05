import BeaverCore
import SwiftUI

/// One file in the grid: the thumbnail on a rounded highlight, then the name and a line of details.
/// Hovering tints the highlight softly; selecting adds an accent ring and an accent tint.
/// A badge in the bottom corner tells when the file or some of its pages are rotated, and
/// the hover controls sit in the top corner, away from the middle where people click to select.
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
                .overlay(alignment: .bottomTrailing) { badge }
                .padding(Constants.highlightPadding)
                .background {
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.selectionRadius, style: .continuous)
                        .fill(highlightFill)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: DesignSystem.Layout.selectionRadius, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(ringOpacity), lineWidth: ringWidth)
                }
                .overlay(alignment: .topLeading) {
                    if isHovering && isEnabled {
                        RotateControlsView(
                            subject: item.name,
                            extra: item.kind == .pdf ? showPagesAction : nil,
                            onRotate: onRotate
                        )
                        .padding(Constants.controlsInset)
                        .transition(.opacity)
                    }
                }

            VStack(spacing: Constants.metaSpacing) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(.primary)
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
        .accessibilityValue(rotationSummary ?? "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var ringOpacity: Double {
        if isSelected { return 1 }
        return showsFocus ? Constants.focusRingOpacity : 0
    }

    private var ringWidth: CGFloat {
        contrast == .increased ? Constants.highContrastRingWidth : Constants.ringWidth
    }

    private var highlightFill: AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color.accentColor.opacity(Constants.selectedTintOpacity)) }
        if isHovering && isEnabled { return AnyShapeStyle(.quinary) }
        return AnyShapeStyle(.clear)
    }

    private var pageRotationCount: Int { item.pdf?.pageRotations.count ?? 0 }

    /// "Rotated 90°" or "3 pages rotated", for the badge tooltip and VoiceOver.
    private var rotationSummary: String? {
        DesignSystem.Card.rotatedBadge(file: item.rotationAngle, rotatedPages: pageRotationCount)
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
        if let rotationSummary {
            HStack(spacing: Constants.badgeSpacing) {
                Image(systemName: DesignSystem.Icons.rotated)
                if item.rotationAngle != .zero {
                    Text(DesignSystem.Card.rotatedBadgeLabel(item.rotationAngle))
                        .monospacedDigit()
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Constants.badgeHorizontalPadding)
            .padding(.vertical, Constants.badgeVerticalPadding)
            .background(Color.accentColor, in: Capsule())
            .shadow(color: .black.opacity(Constants.badgeShadowOpacity), radius: 1, y: 0.5)
            .padding(Constants.badgeInset)
            .help(rotationSummary)
            .accessibilityLabel(rotationSummary)
        }
    }
}

private enum Constants {
    static let labelSpacing: CGFloat = 4
    static let metaSpacing: CGFloat = 2
    static let highlightPadding: CGFloat = 8
    static let ringWidth: CGFloat = 2
    static let highContrastRingWidth: CGFloat = 3
    static let focusRingOpacity: Double = 0.6
    static let selectedTintOpacity: Double = 0.14
    static let controlsInset: CGFloat = 4
    static let hoverDuration: Double = 0.12
    static let badgeSpacing: CGFloat = 3
    static let badgeHorizontalPadding: CGFloat = 6
    static let badgeVerticalPadding: CGFloat = 3
    static let badgeInset: CGFloat = 4
    static let badgeShadowOpacity: Double = 0.2
}
