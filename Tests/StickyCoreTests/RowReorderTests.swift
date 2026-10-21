import XCTest
@testable import StickyCore

final class RowReorderTests: XCTestCase {
    private let h = 28.0
    private func even(_ count: Int) -> [Double] { Array(repeating: h, count: count) }

    func test_tops_stackTheRowsWithSpacingBetween() {
        XCTAssertEqual(RowReorder.tops(heights: [20, 36, 20], spacing: 4), [0, 24, 64])
        XCTAssertEqual(RowReorder.tops(heights: [], spacing: 4), [])
    }

    func test_destination_roundsToTheNearestSlot() {
        XCTAssertEqual(RowReorder.destination(from: 0, translation: 0, heights: even(4), spacing: 0), 0)
        XCTAssertEqual(RowReorder.destination(from: 0, translation: h * 0.6, heights: even(4), spacing: 0), 1)
        XCTAssertEqual(RowReorder.destination(from: 0, translation: h * 1.4, heights: even(4), spacing: 0), 1)
        XCTAssertEqual(RowReorder.destination(from: 2, translation: -h * 1.6, heights: even(4), spacing: 0), 0)
    }

    func test_destination_staysInsideTheList() {
        XCTAssertEqual(RowReorder.destination(from: 1, translation: -h * 10, heights: even(4), spacing: 0), 0)
        XCTAssertEqual(RowReorder.destination(from: 1, translation: h * 10, heights: even(4), spacing: 0), 3)
        XCTAssertEqual(RowReorder.destination(from: 1, translation: h, heights: [], spacing: 0), 1)
        XCTAssertEqual(RowReorder.destination(from: 5, translation: h, heights: even(4), spacing: 0), 5)
    }

    func test_destination_withRowsOfDifferentHeights_picksTheSlotNearestWhereTheRowIs() {
        // A one-line row above a three-line one: in slot 1 it would sit at 52 + 4 = 56, in slot 2 at 80.
        let heights: [Double] = [20, 52, 20]

        XCTAssertEqual(RowReorder.destination(from: 0, translation: 27, heights: heights, spacing: 4), 0)
        XCTAssertEqual(RowReorder.destination(from: 0, translation: 29, heights: heights, spacing: 4), 1)
        XCTAssertEqual(RowReorder.destination(from: 0, translation: 70, heights: heights, spacing: 4), 2)
        // The tall row from 24: slot 0 is at 0, so 11 is nearer that than where it started.
        XCTAssertEqual(RowReorder.destination(from: 1, translation: -13, heights: heights, spacing: 4), 0)
    }

    func test_shift_movesTheRowsTheDraggedRowPasses_byItsHeight() {
        // Dragging row 0 down to slot 2: rows 1 and 2 move up a slot.
        XCTAssertEqual((0..<4).map { RowReorder.shift(row: $0, from: 0, to: 2, heights: even(4), spacing: 0) }, [0, -h, -h, 0])
        // Dragging row 3 up to slot 1: rows 1 and 2 move down a slot.
        XCTAssertEqual((0..<4).map { RowReorder.shift(row: $0, from: 3, to: 1, heights: even(4), spacing: 0) }, [0, h, h, 0])
        XCTAssertEqual((0..<4).map { RowReorder.shift(row: $0, from: 2, to: 2, heights: even(4), spacing: 0) }, [0, 0, 0, 0])
        // A three-line row moving up past a one-line one pushes it down by its own height and gap.
        XCTAssertEqual((0..<3).map { RowReorder.shift(row: $0, from: 1, to: 0, heights: [20, 52, 20], spacing: 4) }, [56, 0, 0])
        XCTAssertEqual(RowReorder.shift(row: 0, from: 9, to: 0, heights: [20], spacing: 4), 0)
    }

    func test_moved_placesTheItemInItsNewSlot_andLeavesTheInputAlone() {
        let items = ["a", "b", "c", "d"]

        XCTAssertEqual(RowReorder.moved(items, from: 0, to: 2), ["b", "c", "a", "d"])
        XCTAssertEqual(RowReorder.moved(items, from: 3, to: 0), ["d", "a", "b", "c"])
        XCTAssertEqual(RowReorder.moved(items, from: 1, to: 1), items)
        XCTAssertEqual(RowReorder.moved(items, from: 9, to: 0), items)
        XCTAssertEqual(RowReorder.moved(items, from: 0, to: 9), items)
        XCTAssertEqual(items, ["a", "b", "c", "d"])
    }
}

final class RowReorderClampTests: XCTestCase {
    private let h = 24.0

    func test_clamped_keepsTheDraggedRowBetweenTheFirstAndLastSlot() {
        // Row 1 of 4 can travel one slot up and two slots down, no further.
        let heights = Array(repeating: h, count: 4)
        XCTAssertEqual(RowReorder.clamped(translation: -100, from: 1, heights: heights, spacing: 0), -h)
        XCTAssertEqual(RowReorder.clamped(translation: 100, from: 1, heights: heights, spacing: 0), 2 * h)
        XCTAssertEqual(RowReorder.clamped(translation: 10, from: 1, heights: heights, spacing: 0), 10)
    }

    func test_clamped_withRowsOfDifferentHeights_reachesTheFirstAndLastSlotExactly() {
        // The tall middle row starts at 24; first slot is 0, last is 20 + 4 + 20 + 4 = 48.
        XCTAssertEqual(RowReorder.clamped(translation: -100, from: 1, heights: [20, 52, 20], spacing: 4), -24)
        XCTAssertEqual(RowReorder.clamped(translation: 100, from: 1, heights: [20, 52, 20], spacing: 4), 24)
    }

    func test_clamped_aSingleRowCannotMove() {
        XCTAssertEqual(RowReorder.clamped(translation: 30, from: 0, heights: [h], spacing: 0), 0)
        XCTAssertEqual(RowReorder.clamped(translation: -30, from: 0, heights: [], spacing: 0), 0)
        XCTAssertEqual(RowReorder.clamped(translation: 30, from: 4, heights: [h, h], spacing: 0), 0)
    }
}
