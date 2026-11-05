#if os(iOS)
import BeaverCore
import SwiftUI

/// Draws scan previews away from the main thread.
enum ScanPreviewRenderer {
    private static let builder = ScanDocumentBuilder()

    /// The page as it will look in the PDF, at most `maxPixelSize` on its longest side.
    @concurrent
    static func preview(of page: ScanPage, maxPixelSize: Int) async -> CGImage? {
        builder.preview(page, maxPixelSize: maxPixelSize)
    }

    /// The photo a page was cut from, upright and uncut, for moving its corners.
    @concurrent
    static func photo(of page: ScanPage, maxPixelSize: Int) async -> CGImage? {
        builder.loadImage(at: page.imageURL, maxPixelSize: maxPixelSize)
    }
}

/// A scanned page as it will appear in the PDF. While a new look is drawn the last one stays
/// on screen, so switching filters doesn't flash.
struct ScanPageImage: View {
    let page: ScanPage
    let maxPixelSize: Int

    @State private var image: CGImage?

    var body: some View {
        ZStack {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: page) {
            let rendered = await ScanPreviewRenderer.preview(of: page, maxPixelSize: maxPixelSize)
            guard !Task.isCancelled else { return }
            image = rendered
        }
    }
}
#endif
