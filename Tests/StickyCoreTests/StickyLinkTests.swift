import XCTest
@testable import StickyCore

final class StickyLinkTests: XCTestCase {
    private let id = UUID(uuidString: "3A752231-35A0-4547-9292-58CAFEECE518")!

    func test_urls() {
        XCTAssertEqual(StickyLink.add.url.absoluteString, "stickynotes://add")
        XCTAssertEqual(StickyLink.edit(id, row: 3).url.absoluteString, "stickynotes://edit/3A752231-35A0-4547-9292-58CAFEECE518?row=3")
        XCTAssertEqual(StickyLink.edit(id, row: nil).url.absoluteString, "stickynotes://edit/3A752231-35A0-4547-9292-58CAFEECE518")
    }

    func test_parsing_roundTripsAndIgnoresCase() {
        XCTAssertEqual(StickyLink(url: StickyLink.add.url), .add)
        XCTAssertEqual(StickyLink(url: StickyLink.edit(id, row: 3).url), .edit(id, row: 3))
        XCTAssertEqual(StickyLink(url: StickyLink.edit(id, row: nil).url), .edit(id, row: nil))
        XCTAssertEqual(StickyLink(url: URL(string: "StickyNotes://ADD/")!), .add)
        XCTAssertEqual(StickyLink(url: URL(string: "stickynotes://Edit/3a752231-35a0-4547-9292-58cafeece518")!), .edit(id, row: nil))
        // A row that isn't a sensible number is ignored rather than failing the whole link.
        XCTAssertEqual(StickyLink(url: URL(string: "stickynotes://edit/\(id.uuidString)?row=-2")!), .edit(id, row: nil))
        XCTAssertEqual(StickyLink(url: URL(string: "stickynotes://edit/\(id.uuidString)?row=abc")!), .edit(id, row: nil))
    }

    func test_parsing_rejectsOtherSchemesActionsAndBadIDs() {
        XCTAssertNil(StickyLink(url: URL(string: "due://add")!))
        XCTAssertNil(StickyLink(url: URL(string: "stickynotes://delete")!))
        XCTAssertNil(StickyLink(url: URL(string: "stickynotes://edit")!))
        XCTAssertNil(StickyLink(url: URL(string: "stickynotes://edit/not-a-uuid")!))
    }
}
