import BeaverCore
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// A sheet with every page of one PDF: rotate single pages, a selection, or all of them, and
/// export the selection (or every page) as a new PDF or as images.
/// Changes go through the reactor at once, so they can be undone and are used by Merge and Split.
/// The sheet starts at a size that fits its pages and can be resized.
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
        .sheetFrame(minimum: CGSize(width: Constants.minWidth, height: Constants.minHeight), ideal: idealSize)
        .accessibilityIdentifier(UITestID.pagesSheet)
        .focusedSceneObject(reactor)
        .exitCommand(perform: close)
        .task {
            pageCount = await thumbnailer.pageCount()
            isGridFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: Constants.titleSpacing) {
                Text(DesignSystem.Pages.title(pdf.url.lastPathComponent))
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(pdf.url.lastPathComponent)
                    .accessibilityLabel(spokenFileName)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.supporting)
                    .monospacedDigit()
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            Button(DesignSystem.Pages.selectAll) {
                selection.selectAll(count: count)
            }
            .keyboardShortcut("a", modifiers: .command)
            .help(DesignSystem.Help.selectAll)
            .disabled(count == 0)
            .fixedSize()
        }
        .padding(DesignSystem.Spacing.contentPadding)
    }

    private var subtitle: String {
        guard let pageCount else { return "" }
        let pages = DesignSystem.Pages.pageCount(pageCount)
        return selection.isEmpty ? pages : "\(pages) · \(DesignSystem.Pages.selectedCount(selection.indexes.count))"
    }

    /// VoiceOver-friendly file name: "sample, PDF" instead of "sample.pdf" (the audit flags dotted names).
    private var spokenFileName: String {
        let url = pdf.url
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.uppercased()
        return ext.isEmpty ? base : "\(base), \(ext)"
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
            .accessibilityHint(DesignSystem.Pages.selectionHint)
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

    /// Rotate the selected pages or all of them, Export, and Done.
    @ViewBuilder
    private var footer: some View {
        #if os(iOS)
        // Icons alone when the titles don't fit, such as on iPhone; VoiceOver still reads them.
        ViewThatFits(in: .horizontal) {
            footerButtons.labelStyle(.titleAndIcon)
            footerButtons.labelStyle(.iconOnly)
        }
        .padding(DesignSystem.Spacing.contentPadding)
        #else
        footerButtons
            .labelStyle(.titleAndIcon)
            .padding(DesignSystem.Spacing.contentPadding)
        #endif
    }

    private var footerButtons: some View {
        HStack(spacing: DesignSystem.Spacing.small) {
            Button {
                rotateSelection(.left)
            } label: {
                Label(DesignSystem.Pages.rotateLeft, systemImage: DesignSystem.Icons.rotateLeft)
            }
            .keyboardShortcut("l", modifiers: .command)
            .help(DesignSystem.Help.rotatePages(.left, hasSelection: !selection.isEmpty))
            .disabled(isDisabled || selection.isEmpty)

            Button {
                rotateSelection(.right)
            } label: {
                Label(DesignSystem.Pages.rotateRight, systemImage: DesignSystem.Icons.rotateRight)
            }
            .keyboardShortcut("r", modifiers: .command)
            .help(DesignSystem.Help.rotatePages(.right, hasSelection: !selection.isEmpty))
            .disabled(isDisabled || selection.isEmpty)

            Menu {
                Button(DesignSystem.Pages.rotateAllPagesLeft) { rotateAllPages(.left) }
                    .help(DesignSystem.Help.rotateAllPagesLeft)
                Button(DesignSystem.Pages.rotateAllPagesRight) { rotateAllPages(.right) }
                    .help(DesignSystem.Help.rotateAllPagesRight)
            } label: {
                Text(DesignSystem.Pages.rotateAllPages)
            }
            .fixedSize()
            .disabled(isDisabled || count == 0)
            .help(DesignSystem.Help.rotateAllPages)

            exportMenu

            Spacer(minLength: DesignSystem.Spacing.medium)

            Button(DesignSystem.Pages.done, action: close)
                .keyboardShortcut(.defaultAction)
                .help(DesignSystem.Help.done)
        }
    }

    /// Saves the selected pages, or every page when none are selected, as one PDF or as one
    /// image per page. The section header says which pages, and each item what it makes.
    private var exportMenu: some View {
        let exportCount = selection.isEmpty ? count : selection.indexes.count
        return Menu {
            Section(DesignSystem.Pages.exportScope(selectedCount: selection.indexes.count)) {
                ForEach(PageExportFormat.allCases, id: \.self) { format in
                    Button {
                        export(format)
                    } label: {
                        #if os(iOS)
                        Label {
                            Text(DesignSystem.Pages.exportTitle(format))
                            Text(DesignSystem.Pages.exportDetail(format, count: exportCount))
                        } icon: {
                            Image(systemName: format == .pdf ? DesignSystem.Icons.pdf : DesignSystem.Icons.image)
                        }
                        #else
                        Text(DesignSystem.Pages.exportTitle(format))
                        #endif
                    }
                    .keyboardShortcut(Self.exportShortcut(format).key, modifiers: Self.exportShortcut(format).modifiers)
                    .help(DesignSystem.Help.exportPages(format, count: exportCount))
                }
            }
        } label: {
            Label(DesignSystem.Pages.export, systemImage: DesignSystem.Icons.exportPages)
                #if os(iOS)
                // The icon alone is small; keep a full touch target when the titles don't fit.
                .frame(minWidth: DesignSystem.Layout.minTouchTarget, minHeight: DesignSystem.Layout.minTouchTarget)
                .contentShape(Rectangle())
                #endif
        }
        .fixedSize()
        .help(DesignSystem.Pages.exportHint)
        .accessibilityHint(DesignSystem.Pages.exportHint)
        .disabled(isDisabled || count == 0)
    }

    /// ⌘E for a PDF; the image formats use the same keys as the Actions menu.
    private static func exportShortcut(_ format: PageExportFormat) -> (key: KeyEquivalent, modifiers: EventModifiers) {
        switch format {
        case .pdf: return ("e", .command)
        case .png: return ("e", [.command, .option])
        case .jpeg: return ("e", [.command, .option, .shift])
        }
    }

    /// Wide enough for up to four pages in a row and tall enough for two rows, within the screen.
    private var idealSize: CGSize {
        let columns = CGFloat(min(max(count, 1), Constants.idealColumns))
        let rows = CGFloat(min(max((count + Constants.idealColumns - 1) / Constants.idealColumns, 1), Constants.idealRows))
        let width = columns * Constants.cellMinimum + (columns - 1) * Constants.gridSpacing
            + 2 * DesignSystem.Spacing.contentPadding
        let height = rows * Constants.cellHeight + (rows - 1) * Constants.gridSpacing
            + 2 * DesignSystem.Spacing.contentPadding + Constants.chromeHeight
        return CGSize(width: max(width, Constants.minWidth), height: max(height, Constants.minHeight))
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

    /// The page view closes and the export continues on the window, where the save panel and
    /// the result banner live.
    private func export(_ format: PageExportFormat) {
        let pages = selection.isEmpty ? nil : selection.sorted
        reactor.send(.exportPages(id: pdf.id, pages: pages, format: format))
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

    /// Solid accent when selected, a lighter ring for keyboard focus alone.
    private var cellRing: Color {
        if isSelected { return .accentColor }
        return isFocused ? Color.accentColor.opacity(Constants.focusRingOpacity) : .clear
    }

    var body: some View {
        VStack(spacing: Constants.cellSpacing) {
            thumbnail
            HStack {
                Text(DesignSystem.Pages.page(index))
                    .font(.callout.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)
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
            RoundedRectangle(cornerRadius: DesignSystem.Layout.selectionRadius, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(Color.accentColor.opacity(Constants.selectedTintOpacity)) : AnyShapeStyle(.quinary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.selectionRadius, style: .continuous)
                .strokeBorder(cellRing, lineWidth: Constants.selectionLineWidth)
        )
        .accessibilityElement(children: .contain)
        .task(id: index) {
            image = await thumbnailer.thumbnail(at: index, maxPixelSize: Constants.thumbnailPixelSize)
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Layout.thumbnailRadius, style: .continuous)
                .fill(.quaternary)

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
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: DesignSystem.Icons.selectedPage)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
                    .font(.title2)
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
    static let minWidth: CGFloat = 560
    static let minHeight: CGFloat = 420
    static let idealColumns = 4
    static let idealRows = 2
    /// A cell at its minimum width: square thumbnail, label row and padding.
    static let cellHeight: CGFloat = 230
    /// Header, footer and their dividers.
    static let chromeHeight: CGFloat = 130
    static let selectedTintOpacity: Double = 0.14
    static let focusRingOpacity: Double = 0.5
    static let titleSpacing: CGFloat = 2
    #if os(iOS)
    /// Two pages side by side on iPhone.
    static let cellMinimum: CGFloat = 140
    #else
    static let cellMinimum: CGFloat = 170
    #endif
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

private extension View {
    /// The Mac sheet starts at a size that fits its pages and can be resized; iOS sheets
    /// take the size the system gives them.
    @ViewBuilder
    func sheetFrame(minimum: CGSize, ideal: CGSize) -> some View {
        #if os(macOS)
        frame(
            minWidth: minimum.width,
            idealWidth: ideal.width,
            maxWidth: .infinity,
            minHeight: minimum.height,
            idealHeight: ideal.height,
            maxHeight: .infinity
        )
        #else
        self
        #endif
    }

    /// Escape closes the sheet on the Mac; iOS sheets close with Done or a swipe.
    @ViewBuilder
    func exitCommand(perform action: @escaping () -> Void) -> some View {
        #if os(macOS)
        onExitCommand(perform: action)
        #else
        self
        #endif
    }
}
