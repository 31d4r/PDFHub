import BeaverCore
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// What a card carries while it is dragged to a new position: only its id.
///
/// It uses a Beaver-only content type that is visible to this process alone, so a
/// reorder drag never offers file URLs (it can't be mistaken for files dropped from
/// Finder), and files dragged from Finder never match a card's reorder target.
struct CardDragItem: Codable, Transferable {
    let id: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .beaverCard)
            .visibility(.ownProcess)
    }
}

extension UTType {
    static let beaverCard = UTType(exportedAs: "com.eldartutnjic.Beaver.card")
}

/// An extra command a card offers in its context menu and to VoiceOver, before the move items.
struct CardAction {
    let title: String
    let systemImage: String
    var isEnabled = true
    let perform: () -> Void
}

/// Lets a grid card be moved: drag it onto another card, or use the context menu
/// or the VoiceOver actions (Move to Beginning, Move Left, Move Right, Move to End).
struct ReorderableCardModifier: ViewModifier {
    let id: UUID
    let index: Int
    let count: Int
    let title: String
    let systemImage: String
    let cornerRadius: CGFloat
    let isEnabled: Bool
    var extraAction: CardAction?
    /// Moves the item with the given id to the given index.
    let onMove: (UUID, Int) -> Void

    @State private var isTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isTargeted ? Constants.targetedScale : 1)
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(DesignSystem.Colors.primaryGradientStart, lineWidth: Constants.targetLineWidth)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: Constants.highlightDuration), value: isTargeted)
            .draggable(CardDragItem(id: id)) {
                dragPreview
            }
            .dropDestination(for: CardDragItem.self) { items, _ in
                guard isEnabled, let item = items.first, item.id != id else { return false }
                move(item.id, to: index)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted && isEnabled
            }
            .contextMenu {
                if let extraAction {
                    Button {
                        extraAction.perform()
                    } label: {
                        Label(extraAction.title, systemImage: extraAction.systemImage)
                    }
                    .disabled(!extraAction.isEnabled)

                    Divider()
                }
                ForEach(MoveDirection.allCases, id: \.self) { direction in
                    Button(Self.label(for: direction)) {
                        moveSelf(direction)
                    }
                    .disabled(!canMove(direction))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityActions {
                if let extraAction, extraAction.isEnabled {
                    Button(extraAction.title, action: extraAction.perform)
                }
                ForEach(MoveDirection.allCases.filter(canMove), id: \.self) { direction in
                    Button(Self.label(for: direction)) {
                        moveSelf(direction)
                    }
                }
            }
    }

    private var dragPreview: some View {
        Label(title, systemImage: systemImage)
            .scaledFont(size: DesignSystem.Typography.fileNameFontSize, weight: .semibold, design: .rounded)
            .foregroundColor(DesignSystem.Colors.titleColor)
            .lineLimit(1)
            .padding(.horizontal, Constants.previewHorizontalPadding)
            .padding(.vertical, Constants.previewVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                    .fill(DesignSystem.Colors.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                    .strokeBorder(DesignSystem.Colors.primaryGradientStart, lineWidth: 1)
            )
    }

    private func canMove(_ direction: MoveDirection) -> Bool {
        isEnabled && direction.destination(from: index, count: count) != nil
    }

    private func moveSelf(_ direction: MoveDirection) {
        guard isEnabled, let destination = direction.destination(from: index, count: count) else { return }
        move(id, to: destination)
    }

    private func move(_ id: UUID, to destination: Int) {
        withAnimation(reduceMotion ? nil : .snappy) {
            onMove(id, destination)
        }
    }

    static func label(for direction: MoveDirection) -> String {
        switch direction {
        case .toStart: return DesignSystem.Reorder.moveToBeginning
        case .previous: return DesignSystem.Reorder.moveLeft
        case .next: return DesignSystem.Reorder.moveRight
        case .toEnd: return DesignSystem.Reorder.moveToEnd
        }
    }
}

extension View {
    func reorderableCard(
        id: UUID,
        index: Int,
        count: Int,
        title: String,
        systemImage: String,
        cornerRadius: CGFloat,
        isEnabled: Bool,
        extraAction: CardAction? = nil,
        onMove: @escaping (UUID, Int) -> Void
    ) -> some View {
        modifier(ReorderableCardModifier(
            id: id,
            index: index,
            count: count,
            title: title,
            systemImage: systemImage,
            cornerRadius: cornerRadius,
            isEnabled: isEnabled,
            extraAction: extraAction,
            onMove: onMove
        ))
    }
}

private enum Constants {
    static let targetedScale: CGFloat = 1.02
    static let targetLineWidth: CGFloat = 3
    static let highlightDuration: Double = 0.15
    static let previewHorizontalPadding: CGFloat = 14
    static let previewVerticalPadding: CGFloat = 10
}
