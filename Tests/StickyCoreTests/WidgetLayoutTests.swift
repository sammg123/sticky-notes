import XCTest
@testable import StickyCore

final class WidgetLayoutTests: XCTestCase {
    // Desktop widget windows are the widget plus an 8pt shadow inset on every side.
    private let largeWindow = CGRect(x: 368, y: 221, width: 360, height: 360)
    private let smallWindow = CGRect(x: 8, y: 41, width: 180, height: 180)

    func test_contentFrame_dropsTheShadowInset() {
        XCTAssertEqual(WidgetLayout.contentFrame(ofWindow: largeWindow), CGRect(x: 376, y: 229, width: 344, height: 344))
    }

    func test_widgetWindow_picksTheWidgetUnderThePointer() {
        let medium = CGRect(x: 368, y: 41, width: 360, height: 180)
        let fullScreen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let windows = [fullScreen, smallWindow, medium, largeWindow]

        XCTAssertEqual(WidgetLayout.widgetWindow(containing: CGPoint(x: 500, y: 300), among: windows), largeWindow)
        XCTAssertEqual(WidgetLayout.widgetWindow(containing: CGPoint(x: 500, y: 100), among: windows), medium)
        XCTAssertEqual(WidgetLayout.widgetWindow(containing: CGPoint(x: 50, y: 100), among: windows), smallWindow)
    }

    func test_widgetWindow_ignoresWindowsThatAreNotWidgetSized() {
        let huge = CGRect(x: 0, y: 0, width: 700, height: 700)
        let sliver = CGRect(x: 0, y: 0, width: 40, height: 400)

        XCTAssertNil(WidgetLayout.widgetWindow(containing: CGPoint(x: 10, y: 10), among: [huge, sliver]))
        XCTAssertNil(WidgetLayout.widgetWindow(containing: CGPoint(x: 1000, y: 900), among: [largeWindow]))
    }

    func test_widgetWindow_acceptsOtherWidgetSizes_likeLargerDisplaysUse() {
        // Widgets are bigger on some displays (170/364/382pt); the layout is measured, not assumed.
        let bigger = CGRect(x: 0, y: 0, width: 364 + 16, height: 382 + 16)

        XCTAssertEqual(WidgetLayout.widgetWindow(containing: CGPoint(x: 100, y: 100), among: [bigger]), bigger)
    }
}

final class WidgetLayoutRowsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 0)
    private let small = CGSize(width: 164, height: 164)
    private let large = CGSize(width: 344, height: 344)

    private func notes(_ count: Int) -> [StickyNote] {
        (0..<count).map { StickyNote(text: "n\($0)", createdAt: t0) }
    }

    /// Lines per note from the note's text ("3 lines" style stand-ins), so tests don't depend on fonts.
    private func lines(_ texts: [Int]) -> (notes: [StickyNote], measure: (String, CGFloat) -> Int) {
        let notes = texts.enumerated().map { StickyNote(text: "\($0.offset):\($0.element)", createdAt: t0) }
        return (notes, { text, _ in Int(text.split(separator: ":")[1])! })
    }

    func test_rowHeight_growsALineAtATime() {
        XCTAssertEqual(WidgetLayout.rowHeight(lines: 1), 20)
        XCTAssertEqual(WidgetLayout.rowHeight(lines: 2), 36)
        XCTAssertEqual(WidgetLayout.rowHeight(lines: 3), 52)
    }

    func test_rows_oneLineNotes_stackByRowAndSpacing() {
        let layout = WidgetLayout.rows(notes(3), contentSize: large) { _, _ in 1 }

        XCTAssertEqual(layout.rows.map(\.top), [0, 24, 48])
        XCTAssertEqual(layout.rows.map(\.lines), [1, 1, 1])
        XCTAssertEqual(layout.hiddenCount, 0)
    }

    func test_rows_tallerNotes_pushTheNextOnesDown() {
        let (notes, measure) = lines([1, 2, 1, 3])

        let layout = WidgetLayout.rows(notes, contentSize: large, lineCount: measure)

        // 20 + 4, then 36 + 4, then 20 + 4.
        XCTAssertEqual(layout.rows.map(\.top), [0, 24, 64, 88])
        XCTAssertEqual(layout.rows.map(\.height), [20, 36, 20, 52])
    }

    func test_rows_capLongNotesAtMaxLines_andGiveEveryNoteALine() {
        let (notes, measure) = lines([9, 0])

        let layout = WidgetLayout.rows(notes, contentSize: large, lineCount: measure)

        XCTAssertEqual(layout.rows.map(\.lines), [WidgetLayout.maxLines, 1])
    }

    func test_rows_measureAtTheTextsWidth_lessTheXOnCrossedOutNotes() {
        let open = StickyNote(text: "open", createdAt: t0)
        let crossed = StickyNote(text: "crossed", isCrossedOut: true, createdAt: t0)
        var widths: [String: CGFloat] = [:]

        _ = WidgetLayout.rows([open, crossed], contentSize: large) { text, width in
            widths[text] = width
            return 1
        }

        // 344 less 16 padding each side, the circle (18) and its gap (8); the x takes 8 + 20 more.
        XCTAssertEqual(widths, ["open": 286, "crossed": 258])
        XCTAssertEqual(WidgetLayout.textWidth(contentWidth: 164, isCrossedOut: false), 106)
    }

    func test_rows_onOverflow_leaveTheLastRowForTheHiddenCount() {
        // A small widget has 102pt under its header: four one-line notes, or three and "N more".
        XCTAssertEqual(WidgetLayout.rows(notes(4), contentSize: small) { _, _ in 1 }.rows.count, 4)

        let layout = WidgetLayout.rows(notes(6), contentSize: small) { _, _ in 1 }

        XCTAssertEqual(layout.rows.map(\.note.text), ["n0", "n1", "n2"])
        XCTAssertEqual(layout.hiddenCount, 3)
    }

    func test_rows_aNoteThatDoesNotFit_isShortenedToTheRoomLeft() {
        // Small widget, 102pt: 52 + 4, then only one line of the second note leaves room for a
        // last row, and the last note fits there itself.
        let (notes, measure) = lines([3, 3, 1])

        let layout = WidgetLayout.rows(notes, contentSize: small, lineCount: measure)

        XCTAssertEqual(layout.rows.map(\.lines), [3, 1, 1])
        XCTAssertEqual(layout.rows.map(\.top), [0, 56, 80])
        XCTAssertEqual(layout.hiddenCount, 0)
    }

    func test_rows_tallNotes_fitFewer_andLeaveTheLastRowForTheHiddenCount() {
        let (notes, measure) = lines([3, 3, 1, 1])

        let layout = WidgetLayout.rows(notes, contentSize: small, lineCount: measure)

        XCTAssertEqual(layout.rows.map(\.lines), [3, 1])
        XCTAssertEqual(layout.hiddenCount, 2)
    }

    func test_rows_theLastNote_takesWhatRoomIsLeft() {
        // Two lines left under a two-line note on a small widget: 36 + 4, then 62pt for a note of 9.
        let (notes, measure) = lines([2, 9])

        XCTAssertEqual(WidgetLayout.rows(notes, contentSize: small, lineCount: measure).rows.map(\.lines), [2, 3])
        XCTAssertEqual(WidgetLayout.rows(notes, contentSize: CGSize(width: 164, height: 130), lineCount: measure).rows.map(\.lines), [2, 1])
    }

    func test_rows_matchTheOneLineCountsEachSizeHadBefore() {
        XCTAssertEqual(WidgetLayout.rows(notes(11), contentSize: large) { _, _ in 1 }.rows.count, 11)
        XCTAssertEqual(WidgetLayout.rows(notes(12), contentSize: large) { _, _ in 1 }.rows.count, 10)
        XCTAssertEqual(WidgetLayout.rows(notes(13), contentSize: CGSize(width: 364, height: 382)) { _, _ in 1 }.rows.count, 13)
    }

    func test_rows_withNoRoomOrNoNotes_showNothing() {
        let none = WidgetLayout.rows(notes(2), contentSize: .zero) { _, _ in 1 }
        XCTAssertEqual(none.rows, [])
        XCTAssertEqual(none.hiddenCount, 2)

        let empty = WidgetLayout.rows([], contentSize: large) { _, _ in 1 }
        XCTAssertEqual(empty.rows, [])
        XCTAssertEqual(empty.hiddenCount, 0)
    }

    func test_rows_measureWithTheRealFontByDefault() {
        let long = StickyNote(text: String(repeating: "word ", count: 30), createdAt: t0)

        XCTAssertEqual(WidgetLayout.rows([long], contentSize: small).rows.first?.lines, WidgetLayout.maxLines)
    }
}

final class WidgetLayoutFramesTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 0)
    private let largeWindow = CGRect(x: 368, y: 221, width: 360, height: 360)

    func test_textFrame_firstRow_sitsUnderTheHeader_besideTheCircle() {
        let row = WidgetLayout.Row(note: StickyNote(text: "a", createdAt: t0), lines: 1, top: 0)

        // x: content 376 + padding 16 + circle 18 + gap 8. y: content 229 + padding 16 + header 22 + 8.
        XCTAssertEqual(WidgetLayout.textFrame(inWindow: largeWindow, row: row), CGRect(x: 418, y: 275, width: 286, height: 20))
    }

    func test_textFrame_coversEveryLine_andMakesRoomForTheX() {
        let row = WidgetLayout.Row(note: StickyNote(text: "a", isCrossedOut: true, createdAt: t0), lines: 2, top: 24)

        XCTAssertEqual(WidgetLayout.textFrame(inWindow: largeWindow, row: row), CGRect(x: 418, y: 299, width: 258, height: 36))
    }

    func test_rowsFrame_coversEveryShownRow_plusAMargin() {
        let rows = [1, 2, 1].reduce(into: [WidgetLayout.Row]()) { rows, lines in
            let top = rows.last.map { $0.top + $0.height + WidgetLayout.rowSpacing } ?? 0
            rows.append(WidgetLayout.Row(note: StickyNote(text: "n", createdAt: t0), lines: lines, top: top))
        }

        // Rows start at y 275 (see textFrame) and take 20 + 4 + 36 + 4 + 20 = 84pt; x spans the
        // content between the paddings (376 + 16 to 720 - 16). The margin is 6pt across, 4pt up and down.
        XCTAssertEqual(WidgetLayout.rowsFrame(inWindow: largeWindow, rows: rows), CGRect(x: 392 - 6, y: 275 - 4, width: 312 + 12, height: 84 + 8))
    }

    func test_rowsFrame_isNil_forNoRows() {
        XCTAssertNil(WidgetLayout.rowsFrame(inWindow: largeWindow, rows: []))
    }
}
