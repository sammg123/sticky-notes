import Foundation

/// The arithmetic behind drag-to-reorder in a list of rows that can differ in height: which slot
/// the dragged row lands in, how far the rows it passes slide out of its way, and the resulting order.
public enum RowReorder {
    /// Each row's top when rows of `heights` are stacked with `spacing` between them.
    public static func tops(heights: [Double], spacing: Double) -> [Double] {
        heights.indices.map { index in heights[..<index].reduce(0) { $0 + $1 + spacing } }
    }

    /// The slot nearest to where the dragged row is now, kept inside the list.
    public static func destination(from index: Int, translation: Double, heights: [Double], spacing: Double) -> Int {
        guard heights.indices.contains(index) else { return index }
        let now = tops(heights: heights, spacing: spacing)[index] + translation
        let slots = slotTops(of: index, heights: heights, spacing: spacing)
        return slots.indices.min { abs(slots[$0] - now) < abs(slots[$1] - now) } ?? index
    }

    /// How far `row` slides while the row at `from` hovers over slot `to`: the rows it has
    /// passed move one dragged row's height (and gap) toward where it came from. The dragged row
    /// itself follows the pointer.
    public static func shift(row: Int, from: Int, to: Int, heights: [Double], spacing: Double) -> Double {
        guard heights.indices.contains(from) else { return 0 }
        let step = heights[from] + spacing
        if from < to, row > from, row <= to { return -step }
        if to < from, row >= to, row < from { return step }
        return 0
    }

    /// `items` with the element at `from` moved to slot `to`. Out-of-range indexes change nothing.
    public static func moved<T>(_ items: [T], from: Int, to: Int) -> [T] {
        guard items.indices.contains(from), items.indices.contains(to), from != to else { return items }
        let rest = items.enumerated().filter { $0.offset != from }.map(\.element)
        return Array(rest[..<to]) + [items[from]] + Array(rest[to...])
    }

    /// `translation` held to what keeps the dragged row between the first and last slot.
    public static func clamped(translation: Double, from index: Int, heights: [Double], spacing: Double) -> Double {
        guard heights.count > 1, heights.indices.contains(index) else { return 0 }
        let start = tops(heights: heights, spacing: spacing)[index]
        let slots = slotTops(of: index, heights: heights, spacing: spacing)
        return min(max(translation, slots[0] - start), slots[slots.count - 1] - start)
    }

    /// Where the row at `index` would start in each slot it could be dropped into.
    private static func slotTops(of index: Int, heights: [Double], spacing: Double) -> [Double] {
        heights.indices.map { slot in tops(heights: moved(heights, from: index, to: slot), spacing: spacing)[slot] }
    }
}
