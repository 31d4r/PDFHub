import AsyncReactor
import BeaverCore
import CoreGraphics
import Foundation
import SwiftUI

/// One scan under review before it becomes a PDF: its pages in order, the page on screen
/// and the name it will be saved under. Only iOS scans, but nothing here needs UIKit, so the
/// tests run on the Mac as well.
final class ScanReactor: AsyncReactor {
    enum Action {
        /// Pages from the document camera, already cut out and flattened by VisionKit.
        case addCaptures([CGImage])
        /// Replaces a page with a new photo of it, in the same place.
        case retake(id: UUID, with: CGImage)
        /// Photos from the library. Vision looks for the page in each one.
        case addPhotos([URL])
        /// Writes the PDF; `state.savedURL` says where.
        case save
    }

    enum SyncAction {
        case showPage(UUID?)
        /// Sets the filter of the page on screen.
        case setFilter(ScanFilter)
        /// Gives every page the filter of the page on screen.
        case applyFilterToAll
        case rotate(id: UUID, direction: RotationDirection)
        /// New corners for a page; ignored unless they make a page shape.
        case setQuad(DocumentQuad, id: UUID)
        case move(fromOffsets: IndexSet, toOffset: Int)
        case delete(Set<UUID>)
        /// A new name; an empty one keeps the old name.
        case rename(String)
        /// Throws the scan away, photos included.
        case discard
        /// Shows a problem found outside the reactor, such as photos that didn't load.
        case showError(String)
        case didDismissError
    }

    enum Activity: Equatable {
        case preparing
        case saving
    }

    struct State {
        var pages: [ScanPage] = []
        var currentPageID: UUID?
        var name: String
        var activity: Activity?
        var errorMessage: String?
        /// The PDF, once saved.
        var savedURL: URL?

        var currentIndex: Int? { pages.firstIndex { $0.id == currentPageID } }
        var currentPage: ScanPage? { currentIndex.map { pages[$0] } }
        var canEdit: Bool { activity == nil && savedURL == nil }
        var canSave: Bool { canEdit && !pages.isEmpty }

        /// Whether Apply to All would change another page.
        var canApplyFilterToAll: Bool {
            guard canEdit, let filter = currentPage?.filter else { return false }
            return pages.contains { $0.filter != filter }
        }

        var isErrorPresented: Bool { errorMessage != nil }
    }

    @Published private(set) var state: State

    private let builder: ScanDocumentBuilder
    private let saveLocationProvider: SaveLocationProviding
    private let defaultName: String

    init(
        builder: ScanDocumentBuilder = ScanDocumentBuilder(),
        saveLocationProvider: SaveLocationProviding = PlatformSaveLocationService(),
        date: Date = .now
    ) {
        self.builder = builder
        self.saveLocationProvider = saveLocationProvider
        self.defaultName = ScanFileName.make(prefix: DesignSystem.Scan.namePrefix, date: date)
        self.state = State(name: defaultName)
    }

    func action(_ action: Action) async {
        switch action {
        case .addCaptures(let images):
            await add { builder in await Self.store(images, using: builder) }
        case .addPhotos(let urls):
            await add { builder in await Self.findPages(in: urls, using: builder) }
        case .retake(let id, let image):
            await retake(id, with: image)
        case .save:
            await save()
        }
    }

    func action(_ action: SyncAction) {
        switch action {
        case .showPage(let id):
            state.currentPageID = id
        case .setFilter(let filter):
            guard state.canEdit, let index = state.currentIndex else { return }
            state.pages[index].filter = filter
        case .applyFilterToAll:
            guard state.canApplyFilterToAll, let filter = state.currentPage?.filter else { return }
            for index in state.pages.indices {
                state.pages[index].filter = filter
            }
        case .rotate(let id, let direction):
            guard state.canEdit, let index = state.pages.firstIndex(where: { $0.id == id }) else { return }
            let rotation = state.pages[index].rotation
            state.pages[index].rotation = direction == .left ? rotation.rotatedLeft : rotation.rotatedRight
        case .setQuad(let quad, let id):
            guard state.canEdit, quad.isConvex,
                  let index = state.pages.firstIndex(where: { $0.id == id }) else { return }
            state.pages[index].quad = quad
        case .move(let offsets, let destination):
            guard state.canEdit else { return }
            state.pages.move(fromOffsets: offsets, toOffset: destination)
        case .delete(let ids):
            delete(ids)
        case .rename(let name):
            if ScanFileName.sanitized(name) != nil {
                state.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case .discard:
            guard state.activity == nil else { return }
            builder.discard(state.pages)
            state.pages = []
            state.currentPageID = nil
        case .showError(let message):
            state.errorMessage = message
        case .didDismissError:
            state.errorMessage = nil
        }
    }

    // MARK: - Adding pages

    private struct Prepared: Sendable {
        var pages: [ScanPage] = []
        var failedCount = 0
    }

    private func add(_ work: @Sendable (ScanDocumentBuilder) async -> Prepared) async {
        guard state.canEdit else { return }
        state.activity = .preparing
        let prepared = await work(builder)
        state.activity = nil
        state.pages.append(contentsOf: prepared.pages)
        if let first = prepared.pages.first {
            state.currentPageID = first.id
        }
        if prepared.failedCount > 0 {
            state.errorMessage = DesignSystem.Scan.pagesFailed(prepared.failedCount)
        }
    }

    @concurrent
    private nonisolated static func store(_ images: [CGImage], using builder: ScanDocumentBuilder) async -> Prepared {
        var prepared = Prepared()
        for image in images {
            if let url = try? builder.store(image) {
                prepared.pages.append(ScanPage(imageURL: url))
            } else {
                prepared.failedCount += 1
            }
        }
        return prepared
    }

    /// Each photo upright by its EXIF orientation, with the page Vision finds in it, or the
    /// whole photo when it finds none.
    @concurrent
    private nonisolated static func findPages(in urls: [URL], using builder: ScanDocumentBuilder) async -> Prepared {
        var prepared = Prepared()
        for url in urls {
            guard let image = builder.loadImage(at: url), let stored = try? builder.store(image) else {
                prepared.failedCount += 1
                continue
            }
            let quad = await DocumentDetector.detect(in: image) ?? .fullImage
            prepared.pages.append(ScanPage(imageURL: stored, quad: quad))
        }
        return prepared
    }

    private func retake(_ id: UUID, with image: CGImage) async {
        guard state.canEdit, state.pages.contains(where: { $0.id == id }) else { return }
        state.activity = .preparing
        let prepared = await Self.store([image], using: builder)
        state.activity = nil
        guard let new = prepared.pages.first, let index = state.pages.firstIndex(where: { $0.id == id }) else {
            state.errorMessage = DesignSystem.Scan.pagesFailed(1)
            return
        }
        let old = state.pages[index]
        builder.discard([old])
        state.pages[index].imageURL = new.imageURL
        state.pages[index].quad = .fullImage
        state.pages[index].rotation = .zero
    }

    private func delete(_ ids: Set<UUID>) {
        guard state.canEdit, !ids.isEmpty else { return }
        let removed = state.pages.filter { ids.contains($0.id) }
        let currentIndex = state.currentIndex ?? 0
        builder.discard(removed)
        state.pages.removeAll { ids.contains($0.id) }
        if let current = state.currentPageID, !ids.contains(current) { return }
        // Show the page that moved into the deleted one's place, or the new last page.
        state.currentPageID = state.pages.isEmpty ? nil : state.pages[min(currentIndex, state.pages.count - 1)].id
    }

    // MARK: - Saving

    private func save() async {
        guard state.canSave else { return }
        let name = ScanFileName.sanitized(state.name) ?? defaultName
        guard let url = saveLocationProvider.saveLocation(defaultName: "\(name).pdf", prompt: DesignSystem.Scan.save) else {
            state.errorMessage = DesignSystem.Scan.saveFailed
            return
        }
        state.activity = .saving
        let pages = state.pages
        let isWritten = await Self.write(pages, to: url, using: builder)
        state.activity = nil
        if isWritten {
            builder.discard(pages)
            state.savedURL = url
        } else {
            state.errorMessage = DesignSystem.Scan.saveFailed
        }
    }

    @concurrent
    private nonisolated static func write(_ pages: [ScanPage], to url: URL, using builder: ScanDocumentBuilder) async -> Bool {
        do {
            try await builder.writePDF(pages, to: url)
            return true
        } catch {
            try? FileManager.default.removeItem(at: url)
            return false
        }
    }
}
