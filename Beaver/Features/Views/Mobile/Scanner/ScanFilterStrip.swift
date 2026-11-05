#if os(iOS)
import BeaverCore
import SwiftUI

/// The four looks for a page, each previewed on the page itself, like the filters in Photos.
struct ScanFilterStrip: View {
    let page: ScanPage
    let isEnabled: Bool
    let onSelect: (ScanFilter) -> Void

    @ScaledMetric(relativeTo: .caption) private var thumbnailSize = DesignSystem.Scan.filterThumbnailSize

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignSystem.Spacing.medium) {
                ForEach(ScanFilter.allCases, id: \.self) { filter in
                    button(for: filter)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.medium)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(DesignSystem.Scan.filter)
        .disabled(!isEnabled)
    }

    private func button(for filter: ScanFilter) -> some View {
        let isSelected = page.filter == filter
        var sample = page
        sample.filter = filter
        return Button {
            onSelect(filter)
        } label: {
            VStack(spacing: DesignSystem.Spacing.small / 2) {
                ScanPageImage(page: sample, maxPixelSize: DesignSystem.Scan.filterPreviewPixels)
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .background(.background.tertiary)
                    .clipShape(.rect(cornerRadius: DesignSystem.Layout.thumbnailRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignSystem.Layout.thumbnailRadius, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2.5)
                    }
                    .accessibilityHidden(true)
                Text(DesignSystem.Scan.filterName(filter))
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(minWidth: DesignSystem.Layout.minTouchTarget, minHeight: DesignSystem.Layout.minTouchTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DesignSystem.Scan.filterName(filter))
        .accessibilityHint(DesignSystem.Scan.filterHelp(filter))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
#endif
