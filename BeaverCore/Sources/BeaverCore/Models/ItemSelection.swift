/// Which items of an ordered list are selected, with Finder-style rules: a click selects one item,
/// ⌘-click toggles one, ⇧-click selects the range from the last plain or ⌘-click (keeping what was
/// selected before that click). Works on ids rather than positions, so a reorder keeps the selection.
public struct ItemSelection<ID: Hashable & Sendable>: Equatable, Sendable {
    public private(set) var ids: Set<ID> = []
    /// Where a ⇧-click range starts.
    public private(set) var anchor: ID?
    /// The item the keyboard moves from.
    public private(set) var focus: ID?
    /// What stays selected around the ⇧-click range.
    private var base: Set<ID> = []

    public init() {}

    public var isEmpty: Bool { ids.isEmpty }
    public var count: Int { ids.count }

    public func contains(_ id: ID) -> Bool {
        ids.contains(id)
    }

    public mutating func click(_ id: ID) {
        ids = [id]
        base = []
        anchor = id
        focus = id
    }

    public mutating func commandClick(_ id: ID) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        base = ids.subtracting([id])
        anchor = id
        focus = id
    }

    /// `order` is the list as shown, used to find the range between the anchor and `id`.
    public mutating func shiftClick(_ id: ID, in order: [ID]) {
        guard let anchor,
              let start = order.firstIndex(of: anchor),
              let end = order.firstIndex(of: id)
        else {
            click(id)
            return
        }
        ids = base.union(order[min(start, end)...max(start, end)])
        focus = id
    }

    public mutating func selectAll(_ order: [ID]) {
        guard let first = order.first else {
            clear()
            return
        }
        ids = Set(order)
        base = []
        if anchor.map(order.contains) != true { anchor = first }
        if focus.map(order.contains) != true { focus = first }
    }

    public mutating func clear() {
        ids = []
        base = []
        anchor = nil
        focus = nil
    }

    /// Forgets items that are no longer in the list.
    public mutating func prune(keeping order: [ID]) {
        let present = Set(order)
        ids.formIntersection(present)
        base.formIntersection(present)
        if let anchor, !present.contains(anchor) { self.anchor = nil }
        if let focus, !present.contains(focus) { self.focus = nil }
    }

    /// Moves the focus by `offset` items (±1 for left/right, ± a row for up/down), clamped to the
    /// list. Selects only that item, or with `extending` (⇧) the range from the anchor.
    public mutating func step(by offset: Int, in order: [ID], extending: Bool) {
        guard !order.isEmpty else { return }
        let targetIndex: Int
        if let focus, let index = order.firstIndex(of: focus) {
            targetIndex = min(max(index + offset, 0), order.count - 1)
        } else {
            targetIndex = offset < 0 ? order.count - 1 : 0
        }
        let target = order[targetIndex]
        if extending {
            shiftClick(target, in: order)
        } else {
            click(target)
        }
    }
}
