import XCTest
@testable import StickyCore

final class WidgetPressTests: XCTestCase {
    private let press = WidgetPress(start: CGPoint(x: 100, y: 200), startTime: 50)

    func test_aQuickPressThatStaysPut_isAClick() {
        XCTAssertFalse(press.isDrag(at: CGPoint(x: 101, y: 202), time: 50.1))
    }

    func test_holdingStill_liftsTheNoteOnceTheHoldDelayPasses() {
        XCTAssertFalse(press.isDrag(at: press.start, time: 50 + WidgetPress.holdDelay - 0.01))
        XCTAssertTrue(press.isDrag(at: press.start, time: 50 + WidgetPress.holdDelay))
    }

    func test_movingPastTheSlop_liftsTheNoteRightAway() {
        XCTAssertFalse(press.isDrag(at: CGPoint(x: 100, y: 200 + WidgetPress.dragSlop), time: 50.05))
        XCTAssertTrue(press.isDrag(at: CGPoint(x: 100, y: 200 + WidgetPress.dragSlop + 0.5), time: 50.05))
        XCTAssertTrue(press.isDrag(at: CGPoint(x: 96, y: 196), time: 50.05))
    }
}
