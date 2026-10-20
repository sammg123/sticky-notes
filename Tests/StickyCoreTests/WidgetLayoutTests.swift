import XCTest
@testable import StickyCore

final class WidgetLayoutTests: XCTestCase {
    // Desktop widget windows are the widget plus an 8pt shadow inset on every side.
    private let largeWindow = CGRect(x: 368, y: 221, width: 360, height: 360)
    private let smallWindow = CGRect(x: 8, y: 41, width: 180, height: 180)

    func test_rowLimit_matchesWhatFitsInEachSize() {
        XCTAssertEqual(WidgetLayout.rowLimit(contentHeight: 164), 4)
        XCTAssertEqual(WidgetLayout.rowLimit(contentHeight: 344), 11)
        XCTAssertEqual(WidgetLayout.rowLimit(contentHeight: 0), 0)
    }

    func test_contentFrame_dropsTheShadowInset() {
        XCTAssertEqual(WidgetLayout.contentFrame(ofWindow: largeWindow), CGRect(x: 376, y: 229, width: 344, height: 344))
    }

    func test_textFrame_firstRow_sitsUnderTheHeader_besideTheCircle() {
        let frame = WidgetLayout.textFrame(inWindow: largeWindow, row: 0, isCrossedOut: false)

        // x: content 376 + padding 16 + circle 18 + gap 8. y: content 229 + padding 16 + header 22 + 8.
        XCTAssertEqual(frame, CGRect(x: 418, y: 275, width: 344 - 42 - 16, height: 20))
    }

    func test_textFrame_laterRows_stepByRowPlusSpacing_andMakeRoomForTheX() {
        let frame = WidgetLayout.textFrame(inWindow: largeWindow, row: 3, isCrossedOut: true)

        XCTAssertEqual(frame?.minY, 275 + 3 * 24)
        XCTAssertEqual(frame?.width, 344 - 42 - 16 - 28)
    }

    func test_textFrame_rowsThatDoNotFit_areNil() {
        XCTAssertNotNil(WidgetLayout.textFrame(inWindow: smallWindow, row: 3, isCrossedOut: false))
        XCTAssertNil(WidgetLayout.textFrame(inWindow: smallWindow, row: 4, isCrossedOut: false))
        XCTAssertNil(WidgetLayout.textFrame(inWindow: smallWindow, row: -1, isCrossedOut: false))
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
        XCTAssertEqual(WidgetLayout.rowLimit(contentHeight: 382), 13)
    }
}

final class WidgetLayoutRowsTests: XCTestCase {
    private let largeWindow = CGRect(x: 368, y: 221, width: 360, height: 360)

    func test_rowsFrame_coversEveryShownRow_plusAMargin() {
        let frame = WidgetLayout.rowsFrame(inWindow: largeWindow, rowCount: 3)

        // Rows start at y 275 (see textFrame) and take 3 * 24 - 4 = 68pt; x spans the content
        // between the paddings (376 + 16 to 720 - 16). The margin is 6pt across, 4pt up and down.
        XCTAssertEqual(frame, CGRect(x: 392 - 6, y: 275 - 4, width: 312 + 12, height: 68 + 8))
    }

    func test_rowsFrame_isNil_forNoRows_orMoreThanFit() {
        XCTAssertNil(WidgetLayout.rowsFrame(inWindow: largeWindow, rowCount: 0))
        XCTAssertNotNil(WidgetLayout.rowsFrame(inWindow: largeWindow, rowCount: 11))
        XCTAssertNil(WidgetLayout.rowsFrame(inWindow: largeWindow, rowCount: 12))
    }

    func test_rowPitch_isARowAndItsSpacing() {
        XCTAssertEqual(WidgetLayout.rowPitch, 24)
    }
}
