import Foundation

/// The arithmetic behind drag-to-reorder in a list of equal-height rows: which slot the dragged
/// row lands in, how far the rows it passes slide out of its way, and the resulting order.
public enum RowReorder {
    /// The slot nearest to where the dragged row is now, kept inside the list.
    public static func destination(from index: Int, translation: Double, rowHeight: Double, count: Int) -> Int {
        guard rowHeight > 0, count > 0 else { return index }
        let slot = index + Int((translation / rowHeight).rounded())
        return min(max(slot, 0), count - 1)
    }

    /// How far `row` slides while the row at `from` hovers over slot `to`: the rows it has
    /// passed move one slot toward where it came from. The dragged row itself follows the pointer.
    public static func shift(row: Int, from: Int, to: Int, rowHeight: Double) -> Double {
        if from < to, row > from, row <= to { return -rowHeight }
        if to < from, row >= to, row < from { return rowHeight }
        return 0
    }

    /// `items` with the element at `from` moved to slot `to`. Out-of-range indexes change nothing.
    public static func moved<T>(_ items: [T], from: Int, to: Int) -> [T] {
        guard items.indices.contains(from), items.indices.contains(to), from != to else { return items }
        let rest = items.enumerated().filter { $0.offset != from }.map(\.element)
        return Array(rest[..<to]) + [items[from]] + Array(rest[to...])
    }

    /// `translation` held to what keeps the dragged row between the first and last slot.
    public static func clamped(translation: Double, from index: Int, rowHeight: Double, count: Int) -> Double {
        guard count > 1 else { return 0 }
        return min(max(translation, -Double(index) * rowHeight), Double(count - 1 - index) * rowHeight)
    }
}
