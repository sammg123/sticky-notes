import XCTest
@testable import StickyCore

final class RowReorderTests: XCTestCase {
    private let h = 28.0

    func test_destination_roundsToTheNearestSlot() {
        XCTAssertEqual(RowReorder.destination(from: 0, translation: 0, rowHeight: h, count: 4), 0)
        XCTAssertEqual(RowReorder.destination(from: 0, translation: h * 0.6, rowHeight: h, count: 4), 1)
        XCTAssertEqual(RowReorder.destination(from: 0, translation: h * 1.4, rowHeight: h, count: 4), 1)
        XCTAssertEqual(RowReorder.destination(from: 2, translation: -h * 1.6, rowHeight: h, count: 4), 0)
    }

    func test_destination_staysInsideTheList() {
        XCTAssertEqual(RowReorder.destination(from: 1, translation: -h * 10, rowHeight: h, count: 4), 0)
        XCTAssertEqual(RowReorder.destination(from: 1, translation: h * 10, rowHeight: h, count: 4), 3)
        XCTAssertEqual(RowReorder.destination(from: 1, translation: h, rowHeight: 0, count: 4), 1)
    }

    func test_shift_movesTheRowsTheDraggedRowPasses() {
        // Dragging row 0 down to slot 2: rows 1 and 2 move up a slot.
        XCTAssertEqual((0..<4).map { RowReorder.shift(row: $0, from: 0, to: 2, rowHeight: h) }, [0, -h, -h, 0])
        // Dragging row 3 up to slot 1: rows 1 and 2 move down a slot.
        XCTAssertEqual((0..<4).map { RowReorder.shift(row: $0, from: 3, to: 1, rowHeight: h) }, [0, h, h, 0])
        XCTAssertEqual((0..<4).map { RowReorder.shift(row: $0, from: 2, to: 2, rowHeight: h) }, [0, 0, 0, 0])
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
