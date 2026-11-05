/// A bounded undo/redo stack of snapshots, each tagged with what the change was
/// (for menu titles like "Undo Rotate All"). Recording a new change clears redo.
public struct UndoHistory<Snapshot: Equatable & Sendable, Label: Equatable & Sendable>: Equatable, Sendable {
    public struct Entry: Equatable, Sendable {
        public let snapshot: Snapshot
        public let label: Label
    }

    public private(set) var undoEntries: [Entry] = []
    public private(set) var redoEntries: [Entry] = []
    /// The oldest entries are dropped past this many.
    public let limit: Int

    public init(limit: Int = 100) {
        self.limit = max(1, limit)
    }

    public var canUndo: Bool { !undoEntries.isEmpty }
    public var canRedo: Bool { !redoEntries.isEmpty }
    public var undoLabel: Label? { undoEntries.last?.label }
    public var redoLabel: Label? { redoEntries.last?.label }

    /// Saves the state from before a change.
    public mutating func record(_ before: Snapshot, label: Label) {
        undoEntries.append(Entry(snapshot: before, label: label))
        if undoEntries.count > limit {
            undoEntries.removeFirst(undoEntries.count - limit)
        }
        redoEntries.removeAll()
    }

    /// The state to go back to, keeping `current` for redo. `nil` when there is nothing to undo.
    public mutating func undo(current: Snapshot) -> Snapshot? {
        guard let entry = undoEntries.popLast() else { return nil }
        redoEntries.append(Entry(snapshot: current, label: entry.label))
        return entry.snapshot
    }

    /// The state to go forward to, keeping `current` for undo. `nil` when there is nothing to redo.
    public mutating func redo(current: Snapshot) -> Snapshot? {
        guard let entry = redoEntries.popLast() else { return nil }
        undoEntries.append(Entry(snapshot: current, label: entry.label))
        return entry.snapshot
    }

    public mutating func removeAll() {
        undoEntries.removeAll()
        redoEntries.removeAll()
    }
}
