import XCTest
@testable import StickyCore

final class StickyLinkTests: XCTestCase {
    func test_addURL() {
        XCTAssertEqual(StickyLink.add.url.absoluteString, "stickynotes://add")
    }

    func test_parsing_roundTripsAndIgnoresCase() {
        for link in StickyLink.allCases {
            XCTAssertEqual(StickyLink(url: link.url), link)
        }
        XCTAssertEqual(StickyLink(url: URL(string: "StickyNotes://ADD/")!), .add)
    }

    func test_parsing_rejectsOtherSchemesAndActions() {
        XCTAssertNil(StickyLink(url: URL(string: "due://add")!))
        XCTAssertNil(StickyLink(url: URL(string: "stickynotes://delete")!))
    }
}
