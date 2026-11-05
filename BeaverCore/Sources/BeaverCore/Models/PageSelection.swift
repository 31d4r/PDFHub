/// Which pages are selected in a page grid, with Finder-style click rules:
/// a click selects one page, ⌘-click toggles a page, ⇧-click selects the range
/// from the last plain or ⌘-click (keeping what was selected before that click).
public struct PageSelection: Equatable, Sendable {
    public private(set) var indexes: Set<Int> = []
    /// Where a ⇧-click range starts.
    public private(set) var anchor: Int?
    /// The page the keyboard moves from.
    public private(set) var focus: Int?
    /// What stays selected around the ⇧-click range.
    private var base: Set<Int> = []

    public init() {}

    public var isEmpty: Bool { indexes.isEmpty }
    public var sorted: [Int] { indexes.sorted() }

    public func contains(_ index: Int) -> Bool {
        indexes.contains(index)
    }

    public mutating func click(_ index: Int) {
        indexes = [index]
        base = []
        anchor = index
        focus = index
    }

    public mutating func commandClick(_ index: Int) {
        if indexes.contains(index) {
            indexes.remove(index)
        } else {
            indexes.insert(index)
        }
        base = indexes.subtracting([index])
        anchor = index
        focus = index
    }

    public mutating func shiftClick(_ index: Int) {
        guard let anchor else {
            click(index)
            return
        }
        indexes = base.union(min(anchor, index)...max(anchor, index))
        focus = index
    }

    public mutating func selectAll(count: Int) {
        guard count > 0 else {
            clear()
            return
        }
        indexes = Set(0..<count)
        base = []
        anchor = anchor.map { min($0, count - 1) } ?? 0
        focus = focus.map { min($0, count - 1) } ?? 0
    }

    public mutating func clear() {
        indexes = []
        base = []
        anchor = nil
        focus = nil
    }

    /// Moves the focus by `offset` pages (±1 for left/right, ± a row for up/down), clamped to the
    /// grid. Selects only that page, or with `extending` (⇧) the range from the anchor.
    public mutating func step(by offset: Int, count: Int, extending: Bool) {
        guard count > 0 else { return }
        let target: Int
        if let focus {
            target = min(max(focus + offset, 0), count - 1)
        } else {
            target = offset < 0 ? count - 1 : 0
        }
        if extending {
            shiftClick(target)
        } else {
            click(target)
        }
    }
}
