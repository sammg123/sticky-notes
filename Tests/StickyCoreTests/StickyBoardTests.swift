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

    private func board(_ spec: String) -> StickyBoard {
        // "a b- c" = open a, crossed-out b, open c, top to bottom.
        StickyBoard(notes: spec.split(separator: " ").map { word in
            StickyNote(text: String(word.prefix { $0 != "-" }), isCrossedOut: word.hasSuffix("-"), createdAt: t0)
        })
    }

    private func spec(_ board: StickyBoard) -> String {
        board.notes.map { $0.text + ($0.isCrossedOut ? "-" : "") }.joined(separator: " ")
    }

    private func id(_ text: String, in board: StickyBoard) -> UUID {
        board.notes.first { $0.text == text }!.id
    }

    func test_crossingOut_movesTheNoteToTheTopOfTheCrossedOutNotes_andLeavesTheOriginalUntouched() {
        // Arrange
        let before = board("e d c b- a-")

        // Act
        let next = before.toggling(id("d", in: before))

        // Assert
        XCTAssertEqual(spec(next), "e c d- b- a-")
        XCTAssertEqual(next.notes.first { $0.text == "d" }?.id, id("d", in: before))
        XCTAssertEqual(spec(before), "e d c b- a-")
    }

    func test_crossingOut_withNothingCrossedOutYet_sendsTheNoteToTheBottom() {
        let before = board("c b a")

        XCTAssertEqual(spec(before.toggling(id("c", in: before))), "b a c-")
        XCTAssertEqual(spec(before.toggling(id("a", in: before))), "c b a-")
    }

    func test_crossingOut_landsBelowTheLastOpenNote_evenIfACrossedOutNoteWasDraggedAboveIt() {
        let before = board("x- b a")

        XCTAssertEqual(spec(before.toggling(id("b", in: before))), "x- a b-")
    }

    func test_bringingANoteBack_putsItAtTheBottomOfTheOpenNotes() {
        let before = board("b a- c-")

        XCTAssertEqual(spec(before.toggling(id("c", in: before))), "b c a-")
        let allCrossed = board("a- b-")
        XCTAssertEqual(spec(allCrossed.toggling(id("b", in: allCrossed))), "b a-")
    }

    func test_crossingOutAndBack_endsAtTheBottomOfTheOpenNotes_andASingleNoteStaysPut() {
        let before = board("a b c")
        let a = id("a", in: before)
        let single = board("a")

        XCTAssertEqual(spec(before.toggling(a)), "b c a-")
        XCTAssertEqual(spec(before.toggling(a).toggling(a)), "b c a")
        XCTAssertEqual(spec(single.toggling(id("a", in: single))), "a-")
    }

    func test_togglingACrossedOutNote_uncrossesIt_andKeepsIt() {
        let board = StickyBoard.empty.adding("a", now: t0).adding("b", now: t0)
        let target = board.notes[1]

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

    func test_ordering_putsNotesInTheGivenOrder() {
        let board = StickyBoard.empty.adding("a", now: t0).adding("b", now: t0).adding("c", now: t0)
        let ids = board.notes.map(\.id) // c, b, a

        let next = board.ordering([ids[2], ids[0], ids[1]])

        XCTAssertEqual(next.notes.map(\.text), ["a", "c", "b"])
        XCTAssertEqual(board.notes.map(\.text), ["c", "b", "a"])
    }

    func test_ordering_keepsNotesAddedSinceTheDragAtTheTop_andIgnoresStrayIDs() {
        let board = StickyBoard.empty.adding("a", now: t0).adding("b", now: t0)
        let dragged = [board.notes[1].id, board.notes[0].id, UUID(), board.notes[1].id] // a, b, gone, dup
        let withNew = board.adding("new", now: t0)

        let next = withNew.ordering(dragged)

        XCTAssertEqual(next.notes.map(\.text), ["new", "a", "b"])
    }

    func test_editing_replacesTheText_andKeepsEverythingElse() {
        let board = StickyBoard.empty.adding("a", now: t0).adding("b", now: t0)
        let target = board.toggling(board.notes[1].id)

        let next = target.editing(target.notes[1].id, text: "  a, but better \n")

        XCTAssertEqual(next.notes.map(\.text), ["b", "a, but better"])
        XCTAssertEqual(next.notes[1].id, target.notes[1].id)
        XCTAssertTrue(next.notes[1].isCrossedOut)
        XCTAssertEqual(next.notes[1].createdAt, t0)
        XCTAssertEqual(target.notes[1].text, "a")
    }

    func test_editing_toBlankOrAnUnknownID_changesNothing_andCapsLength() {
        let board = StickyBoard.empty.adding("a", now: t0)
        let id = board.notes[0].id

        XCTAssertEqual(board.editing(id, text: "   "), board)
        XCTAssertEqual(board.editing(UUID(), text: "x"), board)
        XCTAssertEqual(board.editing(id, text: String(repeating: "z", count: 500)).notes[0].text.count, StickyBoard.maxTextLength)
    }

    func test_moving_putsTheNoteInItsNewPlace_andLeavesTheOriginalUntouched() {
        let board = ["d", "c", "b", "a"].reduce(StickyBoard.empty) { $0.adding($1, now: t0) }
        let a = board.notes[0].id

        let down = board.moving(a, to: 2)

        XCTAssertEqual(down.notes.map(\.text), ["b", "c", "a", "d"])
        XCTAssertEqual(down.moving(a, to: 0).notes.map(\.text), ["a", "b", "c", "d"])
        XCTAssertEqual(board.notes.map(\.text), ["a", "b", "c", "d"])
    }

    func test_moving_keepsTheIndexInsideTheList_andIgnoresUnknownNotes() {
        let board = ["c", "b", "a"].reduce(StickyBoard.empty) { $0.adding($1, now: t0) }

        XCTAssertEqual(board.moving(board.notes[0].id, to: 99).notes.map(\.text), ["b", "c", "a"])
        XCTAssertEqual(board.moving(board.notes[2].id, to: -5).notes.map(\.text), ["c", "a", "b"])
        XCTAssertEqual(board.moving(UUID(), to: 0), board)
    }
}
