/// A one-step or to-the-end move of an item within an ordered list, used by the
/// non-drag reorder controls. Directions are in list order, not screen order, so
/// they read correctly in right-to-left layouts too.
public enum MoveDirection: CaseIterable, Sendable {
    case toStart
    case previous
    case next
    case toEnd

    /// The index the item at `index` moves to, or `nil` when the move is out of
    /// range or would leave the item where it is.
    public func destination(from index: Int, count: Int) -> Int? {
        let range = 0 ..< count
        guard range.contains(index) else { return nil }

        let target: Int
        switch self {
        case .toStart: target = 0
        case .previous: target = index - 1
        case .next: target = index + 1
        case .toEnd: target = count - 1
        }

        return range.contains(target) && target != index ? target : nil
    }
}

extension Array where Element: Identifiable {
    /// Moves the element with `id` so that it ends up at `destination`, shifting
    /// the elements in between. The element keeps all of its own state.
    ///
    /// Returns `false` and leaves the array unchanged when `id` is unknown,
    /// `destination` is out of range, or the element is already there.
    @discardableResult
    public mutating func move(id: Element.ID, to destination: Int) -> Bool {
        guard
            let source = firstIndex(where: { $0.id == id }),
            indices.contains(destination),
            source != destination
        else {
            return false
        }

        insert(remove(at: source), at: destination)
        return true
    }
}
