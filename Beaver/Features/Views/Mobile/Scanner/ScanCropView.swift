#if os(iOS)
import BeaverCore
import SwiftUI

/// Moves the four corners of a page on the photo it came from. Vision's guess is the start;
/// Find Page asks again, and Whole Photo keeps everything. VoiceOver users move each corner
/// with actions, and Done stays off while the corners cross.
struct ScanCropView: View {
    let page: ScanPage
    let onDone: (DocumentQuad) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var quad: DocumentQuad
    @State private var photo: CGImage?
    @State private var isDetecting = false
    @State private var notice: String?
    @State private var activeCorner: DocumentQuad.Corner?

    init(page: ScanPage, onDone: @escaping (DocumentQuad) -> Void) {
        self.page = page
        self.onDone = onDone
        _quad = State(initialValue: page.quad)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.medium) {
                editor
                    .padding(DesignSystem.Scan.handleHitSize / 2 + DesignSystem.Spacing.small)
                footer
                    .padding(.horizontal, DesignSystem.Spacing.medium)
            }
            .padding(.bottom, DesignSystem.Spacing.small)
            .background(.black)
            .environment(\.colorScheme, .dark)
            .navigationTitle(DesignSystem.Scan.cropTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar, .bottomBar)
            .toolbar { toolbar }
        }
        .interactiveDismissDisabled(quad != page.quad)
        .task {
            photo = await ScanPreviewRenderer.photo(of: page, maxPixelSize: DesignSystem.Scan.cropImagePixels)
        }
        .sensoryFeedback(.selection, trigger: activeCorner) { _, corner in corner != nil }
        .sensoryFeedback(.warning, trigger: quad.isConvex) { _, convex in !convex }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        GeometryReader { proxy in
            if let photo {
                let size = Self.fittedSize(of: photo, in: proxy.size)
                ZStack(alignment: .topLeading) {
                    Image(decorative: photo, scale: 1)
                        .resizable()
                        .frame(width: size.width, height: size.height)
                        .accessibilityHidden(true)
                    QuadMask(points: viewPoints(in: size))
                        .fill(.black.opacity(0.5), style: FillStyle(eoFill: true))
                        .allowsHitTesting(false)
                    QuadOutline(points: viewPoints(in: size))
                        .stroke(quad.isConvex ? Color.accentColor : .red, lineWidth: 2)
                        .allowsHitTesting(false)
                    ForEach(DocumentQuad.Corner.allCases, id: \.self) { corner in
                        handle(for: corner, in: size)
                    }
                }
                .frame(width: size.width, height: size.height)
                .coordinateSpace(.named(Self.space))
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func handle(for corner: DocumentQuad.Corner, in size: CGSize) -> some View {
        let point = viewPoint(quad.corners[corner.rawValue], in: size)
        let isActive = activeCorner == corner
        return Circle()
            .fill(.white.opacity(isActive ? 0.35 : 0.15))
            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 3))
            .frame(width: DesignSystem.Scan.handleSize, height: DesignSystem.Scan.handleSize)
            .scaleEffect(isActive ? 1.3 : 1)
            .frame(width: DesignSystem.Scan.handleHitSize, height: DesignSystem.Scan.handleHitSize)
            .contentShape(.circle)
            .position(point)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        activeCorner = corner
                        notice = nil
                        let normalized = CGPoint(
                            x: value.location.x / size.width,
                            y: 1 - value.location.y / size.height
                        )
                        quad = quad.moving(corner, to: normalized)
                    }
                    .onEnded { _ in activeCorner = nil }
            )
            .animation(.snappy(duration: 0.15), value: isActive)
            .accessibilityElement()
            .accessibilityLabel(DesignSystem.Scan.cornerName(corner))
            .accessibilityValue(positionDescription(of: corner))
            .accessibilityAction(named: DesignSystem.Scan.moveUp) { nudge(corner, dx: 0, dy: 1) }
            .accessibilityAction(named: DesignSystem.Scan.moveDown) { nudge(corner, dx: 0, dy: -1) }
            .accessibilityAction(named: DesignSystem.Scan.moveLeft) { nudge(corner, dx: -1, dy: 0) }
            .accessibilityAction(named: DesignSystem.Scan.moveRight) { nudge(corner, dx: 1, dy: 0) }
    }

    @ViewBuilder
    private var footer: some View {
        let text = notice ?? (quad.isConvex ? DesignSystem.Scan.cropInstructions : DesignSystem.Scan.cornersCross)
        Label {
            Text(text)
        } icon: {
            if !quad.isConvex {
                Image(systemName: DesignSystem.Scan.Icons.warning)
                    .foregroundStyle(.yellow)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(DesignSystem.Scan.cancel) { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(DesignSystem.Scan.done) {
                onDone(quad)
                dismiss()
            }
            .fontWeight(.semibold)
            .disabled(!quad.isConvex)
            .accessibilityHint(quad.isConvex ? "" : DesignSystem.Scan.cornersCross)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                Task { await findPage() }
            } label: {
                Label(DesignSystem.Scan.findPage, systemImage: DesignSystem.Scan.Icons.detect)
                    .labelStyle(.titleAndIcon)
            }
            .disabled(photo == nil || isDetecting)
            .accessibilityHint(DesignSystem.Scan.findPageHelp)
            Spacer()
            Button {
                notice = nil
                quad = .fullImage
            } label: {
                Label(DesignSystem.Scan.wholePhoto, systemImage: DesignSystem.Scan.Icons.wholePhoto)
                    .labelStyle(.titleAndIcon)
            }
            .disabled(quad == .fullImage)
            .accessibilityHint(DesignSystem.Scan.wholePhotoHelp)
        }
    }

    // MARK: - Actions

    private func findPage() async {
        guard let photo else { return }
        isDetecting = true
        defer { isDetecting = false }
        if let found = await DocumentDetector.detect(in: photo) {
            notice = nil
            quad = found
        } else {
            notice = DesignSystem.Scan.noPageFound
            AccessibilityNotification.Announcement(DesignSystem.Scan.noPageFound).post()
        }
    }

    private func nudge(_ corner: DocumentQuad.Corner, dx: Double, dy: Double) {
        let current = quad.corners[corner.rawValue]
        let step = DesignSystem.Scan.cornerStep
        quad = quad.moving(corner, to: CGPoint(x: current.x + dx * step, y: current.y + dy * step))
    }

    // MARK: - Geometry

    private static let space = "scanCrop"

    /// The photo's size scaled to fit `bounds` without cropping.
    private static func fittedSize(of image: CGImage, in bounds: CGSize) -> CGSize {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard width > 0, height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / width, bounds.height / height)
        return CGSize(width: width * scale, height: height * scale)
    }

    /// A corner's spot on screen. The quad counts up from the bottom; the screen counts down.
    private func viewPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
    }

    private func viewPoints(in size: CGSize) -> [CGPoint] {
        quad.corners.map { viewPoint($0, in: size) }
    }

    private func positionDescription(of corner: DocumentQuad.Corner) -> String {
        let point = quad.corners[corner.rawValue]
        return DesignSystem.Scan.cornerPosition(
            fromLeft: Int((point.x * 100).rounded()),
            fromTop: Int(((1 - point.y) * 100).rounded())
        )
    }
}

/// Everything outside the page, dimmed.
private struct QuadMask: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

/// The page's edges.
private struct QuadOutline: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}
#endif
