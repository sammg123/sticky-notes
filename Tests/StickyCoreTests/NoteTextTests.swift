import XCTest
@testable import StickyCore

final class NoteTextTests: XCTestCase {
    func test_lineCount_shortText_isOneLine() {
        XCTAssertEqual(NoteText.lineCount("Call the dentist", width: 286), 1)
        XCTAssertEqual(NoteText.lineCount("", width: 286), 1)
    }

    func test_lineCount_wrapsAtWordsLikeTheWidgetsText() {
        // Measured against SwiftUI's Text at 13pt: 30 four-letter words take 10 lines at 120pt.
        let words = Array(repeating: "word", count: 30).joined(separator: " ")

        XCTAssertEqual(NoteText.lineCount(words, width: 120), 10)
        XCTAssertEqual(NoteText.lineCount("Pick up dry cleaning before the place closes at six tonight", width: 106), 4)
    }

    func test_lineCount_countsLineBreaksInTheText() {
        XCTAssertEqual(NoteText.lineCount("milk\neggs\nbread", width: 286), 3)
    }

    func test_lineCount_withNoRoom_isOneLine() {
        XCTAssertEqual(NoteText.lineCount("anything at all", width: 0), 1)
        XCTAssertEqual(NoteText.lineCount("anything at all", width: -5), 1)
    }

    func test_lineHeight_isWhatSwiftUIDrawsA13ptLineIn() {
        XCTAssertEqual(NoteText.lineHeight, 16)
    }
}
