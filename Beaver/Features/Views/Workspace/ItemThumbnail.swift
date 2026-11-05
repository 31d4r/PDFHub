import BeaverCore
import SwiftUI

/// Shared by every card, so a PDF's first page is drawn once however often its card reappears.
enum Previews {
    static let cache = PDFPreviewCache()
}

/// A file's first page or image, aspect-fit, turned by the user's rotation. Turns animate the
/// short way round (270° to 0° is a quarter turn) and not at all with Reduce Motion.
struct ItemThumbnail: View {
    let item: WorkspaceItem
    /// Called with the page count once a PDF is read.
    var onPageCount: (Int) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var pdfPreview: CGImage?
    @State private var isLoading = false
    /// The angle on screen, in degrees. Unbounded so a turn always animates the short way.
    @State private var displayedDegrees: Double

    init(item: WorkspaceItem, onPageCount: @escaping (Int) -> Void = { _ in }) {
        self.item = item
        self.onPageCount = onPageCount
        _displayedDegrees = State(initialValue: Double(Self.angle(of: item).degrees))
    }

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                            .strokeBorder(
                                contrast == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(.separator),
                                lineWidth: contrast == .increased ? 1 : Constants.hairline
                            )
                    }
                    .shadow(color: .black.opacity(Constants.shadowOpacity), radius: Constants.shadowRadius, y: 1)
                    .rotationEffect(.degrees(displayedDegrees))
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: item.kind == .pdf ? DesignSystem.Icons.unreadable : DesignSystem.Icons.image)
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: Self.angle(of: item)) { old, new in
            withAnimation(reduceMotion ? nil : .easeInOut(duration: DesignSystem.Layout.rotateAnimationDuration)) {
                displayedDegrees += Double(old.shortestTurn(to: new))
            }
        }
        .task(id: item.url) {
            guard item.kind == .pdf else { return }
            isLoading = pdfPreview == nil
            let preview = await Previews.cache.preview(for: item.url, maxPixelSize: DesignSystem.Layout.previewPixelSize)
            pdfPreview = preview.image
            isLoading = false
            onPageCount(preview.pageCount)
        }
    }

    private var image: CGImage? {
        switch item {
        case .pdf: return pdfPreview
        case .image(let image): return image.thumbnail
        }
    }

    /// The turn shown on the thumbnail: for a PDF, its first page's.
    static func angle(of item: WorkspaceItem) -> RotationAngle {
        switch item {
        case .pdf(let pdf): return pdf.rotation.userRotation(forPage: 0)
        case .image(let image): return image.rotationAngle
        }
    }
}

private enum Constants {
    static let cornerRadius: CGFloat = 4
    static let hairline: CGFloat = 0.5
    static let shadowOpacity: Double = 0.18
    static let shadowRadius: CGFloat = 3
}
