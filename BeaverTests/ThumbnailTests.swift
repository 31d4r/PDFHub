import BeaverCore
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Beaver

struct ThumbnailTests {
    private let service = ImageService()

    @Test func thumbnailFitsWithinMaxPixelSize() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("beaver-thumb-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let destination = try #require(
            CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        )
        CGImageDestinationAddImage(destination, TestImages.solid(width: 1600, height: 400), nil)
        #expect(CGImageDestinationFinalize(destination))

        let thumbnail = try #require(service.thumbnail(for: url, maxPixelSize: 200))
        #expect(max(thumbnail.width, thumbnail.height) <= 200)
        #expect(thumbnail.width > thumbnail.height)
    }

    @Test func thumbnailOfMissingFileIsNil() {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).png")
        #expect(service.thumbnail(for: missing, maxPixelSize: 200) == nil)
    }

    @MainActor
    @Test func unreadableImagesAreReportedAndNotAdded() async {
        let missing = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).png")
        let reactor = BeaverReactor(
            saveLocationProvider: MockSaveLocationProvider(),
            imageService: MockImageService()
        )

        await reactor.action(.addImages([missing]))

        #expect(reactor.state.selectedImages.isEmpty)
        #expect(reactor.state.screen == .menu)
    }
}
