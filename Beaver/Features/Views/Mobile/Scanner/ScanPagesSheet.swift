#if os(iOS)
import BeaverCore
import SwiftUI

/// Every page of the scan in a list: tap one to show it, Edit to drag pages into a new order
/// or delete them.
struct ScanPagesSheet: View {
    @EnvironmentObject private var reactor: ScanReactor
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var thumbnailHeight: CGFloat = 64

    private var state: ScanReactor.State { reactor.state }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(state.pages.enumerated()), id: \.element.id) { index, page in
                    row(page, number: index + 1)
                }
                .onMove { offsets, destination in
                    reactor.action(.move(fromOffsets: offsets, toOffset: destination))
                }
                .onDelete { offsets in
                    reactor.action(.delete(Set(offsets.map { state.pages[$0].id })))
                }
            }
            .overlay {
                if state.pages.isEmpty {
                    ContentUnavailableView(
                        DesignSystem.Scan.noPagesTitle,
                        systemImage: DesignSystem.Scan.Icons.scan,
                        description: Text(DesignSystem.Scan.noPagesMessage)
                    )
                }
            }
            .navigationTitle(DesignSystem.Scan.pages)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .disabled(state.pages.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(DesignSystem.Scan.done) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.impact(weight: .light), trigger: state.pages.map(\.id))
    }

    private func row(_ page: ScanPage, number: Int) -> some View {
        let isCurrent = page.id == state.currentPageID
        return Button {
            reactor.action(.showPage(page.id))
            dismiss()
        } label: {
            HStack(spacing: DesignSystem.Spacing.medium) {
                ScanPageImage(page: page, maxPixelSize: DesignSystem.Scan.pageThumbnailPixels)
                    .frame(width: thumbnailHeight * 0.75, height: thumbnailHeight)
                    .clipShape(.rect(cornerRadius: 4, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(DesignSystem.Scan.pageTitle(number))
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(DesignSystem.Scan.filterName(page.filter))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: DesignSystem.Scan.Icons.current)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }
}
#endif
