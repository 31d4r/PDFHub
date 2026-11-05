import BeaverCore
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A sheet with every page of one PDF: rotate single pages, a selection, or all of them.
/// Changes go through the reactor at once, so they can be undone and are used by Merge and Split.
struct PDFPagesView: View {
    @EnvironmentObject private var reactor: BeaverReactor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let pdf: PDFItem

    @State private var thumbnailer: PDFPageThumbnailer
    /// `nil` while loading.
    @State private var pageCount: Int?
    @State private var selection = PageSelection()
    @State private var columnCount = 1
    @FocusState private var isGridFocused: Bool

    init(pdf: PDFItem) {
        self.pdf = pdf
        _thumbnailer = State(initialValue: PDFPageThumbnailer(url: pdf.url))
    }

    private var isDisabled: Bool { reactor.state.activity != nil }
    private var count: Int { pageCount ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            grid
            Divider()
            footer
        }
        .frame(
            minWidth: Constants.minWidth,
            idealWidth: Constants.idealWidth,
            minHeight: Constants.minHeight,
            idealHeight: Constants.idealHeight
        )
        .focusedSceneObject(reactor)
        .onExitCommand(perform: close)
        .task {
            pageCount = await thumbnailer.pageCount()
            isGridFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.buttonSpacing) {
            VStack(alignment: .leading, spacing: Constants.titleSpacing) {
                Text(DesignSystem.Pages.title(pdf.url.lastPathComponent))
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: DesignSystem.Spacing.medium)

            Button(DesignSystem.Pages.selectAll) {
                selection.selectAll(count: count)
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(count == 0)

            ControlGroup {
                Button {
                    rotateSelection(.left)
                } label: {
                    Label(DesignSystem.Pages.rotateSelectedLeft, systemImage: DesignSystem.Icons.rotateLeftIcon)
                }
                .keyboardShortcut("l", modifiers: .command)
                .help(DesignSystem.Pages.rotateSelectedLeft)

                Button {
                    rotateSelection(.right)
                } label: {
                    Label(DesignSystem.Pages.rotateSelectedRight, systemImage: DesignSystem.Icons.rotateRightIcon)
                }
                .keyboardShortcut("r", modifiers: .command)
                .help(DesignSystem.Pages.rotateSelectedRight)
            }
            .labelStyle(.iconOnly)
            .fixedSize()
            .disabled(isDisabled || selection.isEmpty)

            Menu {
                Button(DesignSystem.Pages.rotateAllPagesLeft) { rotateAllPages(.left) }
                Button(DesignSystem.Pages.rotateAllPagesRight) { rotateAllPages(.right) }
            } label: {
                Label(DesignSystem.Pages.rotateAllPages, systemImage: DesignSystem.Icons.rotateRightIcon)
            }
            .fixedSize()
            .disabled(isDisabled || count == 0)
            .help(DesignSystem.Pages.rotateAllPages)
        }
        .padding(DesignSystem.Spacing.contentPadding)
    }

    private var subtitle: String {
        guard let pageCount else { return "" }
        let pages = DesignSystem.Pages.pageCount(pageCount)
        return selection.isEmpty ? pages : "\(pages) · \(DesignSystem.Pages.selectedCount(selection.indexes.count))"
    }

    // MARK: - Grid

    @ViewBuilder
    private var grid: some View {
        if let pageCount {
            if pageCount == 0 {
                ContentUnavailableView(DesignSystem.Pages.unreadable, systemImage: "doc.questionmark")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                pageGrid
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var pageGrid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: Constants.cellMinimum), spacing: Constants.gridSpacing)],
                    spacing: Constants.gridSpacing
                ) {
                    ForEach(0..<count, id: \.self) { index in
                        PageThumbnailCell(
                            index: index,
                            rotation: pdf.rotation.userRotation(forPage: index),
                            isSelected: selection.contains(index),
                            isFocused: isGridFocused && selection.focus == index,
                            isDisabled: isDisabled,
                            thumbnailer: thumbnailer,
                            onSelect: { select(index) },
                            onToggle: { selection.commandClick(index) },
                            onRotate: { direction in rotate([index], direction) }
                        )
                        .id(index)
                    }
                }
                .padding(DesignSystem.Spacing.contentPadding)
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear { updateColumns(width: geometry.size.width) }
                            .onChange(of: geometry.size.width) { _, width in updateColumns(width: width) }
                    }
                }
            }
            .focusable()
            .focused($isGridFocused)
            .focusEffectDisabled()
            .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
                step(press.key, extending: press.modifiers.contains(.shift))
                if let focus = selection.focus {
                    withAnimation(reduceMotion ? nil : .easeInOut) {
                        proxy.scrollTo(focus)
                    }
                }
                return .handled
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(DesignSystem.Pages.selectionHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button(DesignSystem.Pages.done, action: close)
                .keyboardShortcut(.defaultAction)
        }
        .padding(DesignSystem.Spacing.contentPadding)
    }

    // MARK: - Actions

    private func select(_ index: Int) {
        isGridFocused = true
        #if os(macOS)
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) {
            selection.shiftClick(index)
        } else if flags.contains(.command) {
            selection.commandClick(index)
        } else {
            selection.click(index)
        }
        #else
        selection.commandClick(index)
        #endif
    }

    private func step(_ key: KeyEquivalent, extending: Bool) {
        let offset: Int
        switch key {
        case .leftArrow: offset = -1
        case .rightArrow: offset = 1
        case .upArrow: offset = -columnCount
        default: offset = columnCount
        }
        selection.step(by: offset, count: count, extending: extending)
    }

    private func updateColumns(width: CGFloat) {
        let available = width - 2 * DesignSystem.Spacing.contentPadding
        columnCount = max(1, Int((available + Constants.gridSpacing) / (Constants.cellMinimum + Constants.gridSpacing)))
    }

    private func rotateSelection(_ direction: RotationDirection) {
        rotate(selection.sorted, direction)
    }

    private func rotate(_ pages: [Int], _ direction: RotationDirection) {
        guard !pages.isEmpty else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: DesignSystem.Layout.rotateAnimationDuration)) {
            reactor.action(.rotatePages(id: pdf.id, pages: pages, direction: direction))
        }
    }

    private func rotateAllPages(_ direction: RotationDirection) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: DesignSystem.Layout.rotateAnimationDuration)) {
            reactor.action(.rotateAllPages(id: pdf.id, direction: direction))
        }
    }

    private func close() {
        reactor.action(.didChangePagesPresented(false))
    }
}

/// One page in the page view: a thumbnail you click to select, and its own rotate buttons.
private struct PageThumbnailCell: View {
    let index: Int
    /// The user's turn for this page (file plus page), shown on top of the saved rotation.
    let rotation: RotationAngle
    let isSelected: Bool
    let isFocused: Bool
    let isDisabled: Bool
    let thumbnailer: PDFPageThumbnailer
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onRotate: (RotationDirection) -> Void

    @State private var image: CGImage?

    var body: some View {
        VStack(spacing: Constants.cellSpacing) {
            thumbnail
            HStack {
                Text(DesignSystem.Pages.page(index))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.titleColor)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                RotateControlsView(
                    subject: DesignSystem.Pages.page(index),
                    isDisabled: isDisabled,
                    onRotate: onRotate
                )
            }
        }
        .padding(Constants.cellPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.cardSmall, style: .continuous)
                .fill(DesignSystem.Colors.cardSurface)
        )
        .accessibilityElement(children: .contain)
        .task(id: index) {
            image = await thumbnailer.thumbnail(at: index, maxPixelSize: Constants.thumbnailPixelSize)
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.pdfView, style: .continuous)
                .fill(DesignSystem.Colors.pdfContainerBackgroundColor)

            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .shadow(color: .black.opacity(Constants.pageShadowOpacity), radius: Constants.pageShadowRadius)
                    .rotationEffect(.degrees(Double(rotation.degrees)))
                    .padding(Constants.thumbnailInset)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.pdfView, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : (isFocused ? Color.accentColor.opacity(0.5) : .clear),
                    lineWidth: Constants.selectionLineWidth
                )
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: DesignSystem.Icons.selectedPageIcon)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .font(.title3)
                    .padding(Constants.checkmarkPadding)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .accessibilityElement()
        .accessibilityLabel(DesignSystem.Pages.pageAccessibilityLabel(index, rotation: rotation))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(.default, onToggle)
    }
}

private enum Constants {
    static let minWidth: CGFloat = 640
    static let idealWidth: CGFloat = 820
    static let minHeight: CGFloat = 480
    static let idealHeight: CGFloat = 640
    static let titleSpacing: CGFloat = 2
    static let cellMinimum: CGFloat = 170
    static let gridSpacing: CGFloat = 16
    static let cellSpacing: CGFloat = 8
    static let cellPadding: CGFloat = 10
    static let thumbnailInset: CGFloat = 10
    static let thumbnailPixelSize = 360
    static let selectionLineWidth: CGFloat = 3
    static let checkmarkPadding: CGFloat = 6
    static let pageShadowOpacity: Double = 0.15
    static let pageShadowRadius: CGFloat = 3
}
