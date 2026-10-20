import XCTest
@testable import StickyCore

final class DesktopWindowTests: XCTestCase {
    private let ours = DesktopWindow(number: 87645, frame: CGRect(x: 368, y: 221, width: 360, height: 360), layer: -2147483601)
    private let weather = DesktopWindow(number: 27, frame: CGRect(x: 728, y: 41, width: 180, height: 180), layer: -2147483601)

    func test_current_followsTheSameWindow_evenAfterItMoves() {
        let moved = DesktopWindow(number: ours.number, frame: ours.frame.offsetBy(dx: 0, dy: 180), layer: ours.layer)

        XCTAssertEqual(DesktopWindow.current(ours, among: [weather, moved]), moved)
    }

    func test_current_whenTheWindowIsGone_takesTheWidgetWhereItWas() {
        // The widget service restarted and drew our widget in a new window at the same spot.
        let redrawn = DesktopWindow(number: 90001, frame: ours.frame, layer: ours.layer)

        XCTAssertEqual(DesktopWindow.current(ours, among: [weather, redrawn]), redrawn)
    }

    func test_current_isNil_whenNothingMatches() {
        XCTAssertNil(DesktopWindow.current(ours, among: [weather]))
        XCTAssertNil(DesktopWindow.current(ours, among: []))
    }

    func test_codable_roundTrips() throws {
        let data = try JSONEncoder().encode(ours)

        XCTAssertEqual(try JSONDecoder().decode(DesktopWindow.self, from: data), ours)
    }

    func test_widgetWindow_returnsTheWindowUnderThePointer_withItsNumber() {
        let fullScreen = DesktopWindow(number: 18, frame: CGRect(x: 0, y: 0, width: 1512, height: 982), layer: 21)

        XCTAssertEqual(WidgetLayout.widgetWindow(containing: CGPoint(x: 500, y: 300), among: [fullScreen, weather, ours]), ours)
        XCTAssertNil(WidgetLayout.widgetWindow(containing: CGPoint(x: 1400, y: 900), among: [fullScreen, weather, ours]))
    }
}

final class DesktopWindowMemoryTests: XCTestCase {
    private func window(_ number: Int, x: CGFloat = 0) -> DesktopWindow {
        DesktopWindow(number: number, frame: CGRect(x: x, y: 0, width: 360, height: 360), layer: -2147483601)
    }

    func test_remembering_putsTheLatestFirst_withoutRepeatingAWindow() {
        let list = [window(1), window(2), window(3)]

        let next = DesktopWindow.remembering(window(2, x: 50), in: list)

        XCTAssertEqual(next, [window(2, x: 50), window(1), window(3)])
        XCTAssertEqual(list, [window(1), window(2), window(3)])
    }

    func test_remembering_keepsOnlyTheMostRecent() {
        let list = (1...DesktopWindow.rememberedLimit).map { window($0) }

        let next = DesktopWindow.remembering(window(99), in: list)

        XCTAssertEqual(next.count, DesktopWindow.rememberedLimit)
        XCTAssertEqual(next.first, window(99))
        XCTAssertFalse(next.contains(window(DesktopWindow.rememberedLimit)))
    }
}
