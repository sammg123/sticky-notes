import XCTest
@testable import StickyCore

final class StickyBoardTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func test_adding_putsTheNewNoteFirst_andLeavesTheOriginalUntouched() {
        // Arrange
        let board = StickyBoard.empty.adding("first", now: t0)

        // Act
        let next = board.adding("second", now: t0.addingTimeInterval(60))

        // Assert
        XCTAssertEqual(next.notes.map(\.text), ["second", "first"])
        XCTAssertEqual(board.notes.map(\.text), ["first"])
        XCTAssertFalse(next.notes[0].isCrossedOut)
        XCTAssertEqual(next.notes[0].createdAt, t0.addingTimeInterval(60))
    }

    func test_adding_trimsWhitespace_andIgnoresBlankText() {
        let board = StickyBoard.empty.adding("  buy milk \n", now: t0)

        XCTAssertEqual(board.notes.map(\.text), ["buy milk"])
        XCTAssertEqual(board.adding("   \n ", now: t0), board)
        XCTAssertEqual(board.adding("", now: t0), board)
    }

    func test_adding_capsVeryLongText() {
        let long = String(repeating: "a", count: StickyBoard.maxTextLength + 50)

        let board = StickyBoard.empty.adding(long, now: t0)

        XCTAssertEqual(board.notes[0].text.count, StickyBoard.maxTextLength)
    }

    func test_toggling_crossesTheNoteOut_inPlace() {
        let board = StickyBoard.empty.adding("a", now: t0).adding("b", now: t0)
        let target = board.notes[1]

        let next = board.toggling(target.id)

        XCTAssertEqual(next.notes.map(\.text), ["b", "a"])
        XCTAssertEqual(next.notes.map(\.isCrossedOut), [false, true])
        XCTAssertFalse(board.notes[1].isCrossedOut)
    }

    func test_togglingACrossedOutNote_uncrossesIt_andKeepsIt() {
        let board = StickyBoard.empty.adding("a", now: t0).adding("b", now: t0)
        let target = board.notes[0]

        let next = board.toggling(target.id).toggling(target.id)

        XCTAssertEqual(next, board)
    }

    func test_removing_deletesOnlyThatNote() {
        let board = StickyBoard.empty.adding("a", now: t0).adding("b", now: t0)
        let target = board.notes[0]

        let next = board.toggling(target.id).removing(target.id)

        XCTAssertEqual(next.notes.map(\.text), ["a"])
    }

    func test_anUnknownID_changesNothing() {
        let board = StickyBoard.empty.adding("a", now: t0)

        XCTAssertEqual(board.toggling(UUID()), board)
        XCTAssertEqual(board.removing(UUID()), board)
    }

    func test_visible_whenEverythingFits_showsAllNotes() {
        let board = (0..<4).reduce(StickyBoard.empty) { b, i in b.adding("n\(i)", now: t0) }

        let shown = board.visible(limit: 4)

        XCTAssertEqual(shown.notes.map(\.text), ["n3", "n2", "n1", "n0"])
        XCTAssertEqual(shown.hiddenCount, 0)
    }

    func test_visible_onOverflow_givesTheLastRowToTheHiddenCount() {
        let board = (0..<6).reduce(StickyBoard.empty) { b, i in b.adding("n\(i)", now: t0) }

        let shown = board.visible(limit: 4)

        XCTAssertEqual(shown.notes.map(\.text), ["n5", "n4", "n3"])
        XCTAssertEqual(shown.hiddenCount, 3)
    }

    func test_visible_withNoRows_hidesEverything() {
        let board = StickyBoard.empty.adding("a", now: t0).adding("b", now: t0)

        XCTAssertEqual(board.visible(limit: 0).notes, [])
        XCTAssertEqual(board.visible(limit: -1).hiddenCount, 2)
        XCTAssertEqual(board.visible(limit: 1).hiddenCount, 2)
    }
}
