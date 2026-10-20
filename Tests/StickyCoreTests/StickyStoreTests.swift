import XCTest
@testable import StickyCore

final class StickyStoreTests: XCTestCase {
    private var tempRoot: URL!
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempRoot)
        super.tearDown()
    }

    private var store: StickyStore { StickyStore(url: tempRoot.appendingPathComponent("notes.json")) }

    func test_load_missingFile_isAnEmptyBoard() throws {
        XCTAssertEqual(try store.load(), .empty)
    }

    func test_saveThenLoad_roundTrips() throws {
        let board = StickyBoard.empty.adding("a", now: t0).adding("b", now: t0)
        let crossed = board.toggling(board.notes[0].id)

        try store.save(crossed)

        XCTAssertEqual(try store.load(), crossed)
    }

    func test_update_appliesTheChangeToWhatIsOnDisk_andSavesIt() throws {
        try store.save(StickyBoard.empty.adding("on disk", now: t0))

        let result = try store.update { $0.adding("new", now: self.t0) }

        XCTAssertEqual(result.notes.map(\.text), ["new", "on disk"])
        XCTAssertEqual(try store.load(), result)
    }

    func test_load_corruptFile_isSetAside_andStartsEmpty() throws {
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.url)

        let board = try store.load()

        XCTAssertEqual(board, .empty)
        let saved = try FileManager.default.contentsOfDirectory(atPath: tempRoot.path)
            .filter { $0.hasPrefix("notes.corrupt-") && $0.hasSuffix(".json") }
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(try Data(contentsOf: tempRoot.appendingPathComponent(saved[0])), Data("not json".utf8))
        XCTAssertEqual(try store.update { $0.adding("fresh", now: self.t0) }.notes.map(\.text), ["fresh"])
    }

    func test_update_fromManyThreadsAtOnce_losesNothing() throws {
        let count = 40

        DispatchQueue.concurrentPerform(iterations: count) { i in
            // Each call builds its own store, as the app and each widget press do.
            _ = try? StickyStore(url: self.store.url).update { $0.adding("note \(i)", now: self.t0) }
        }

        XCTAssertEqual(try store.load().notes.count, count)
    }

    func test_defaultURL_honorsTheOverride_elseApplicationSupport() {
        XCTAssertEqual(
            StickyStore.defaultURL(environment: ["STICKY_NOTES_PATH": "/tmp/s/notes.json"]).path,
            "/tmp/s/notes.json"
        )
        XCTAssertEqual(
            StickyStore.defaultURL(environment: [:], home: URL(fileURLWithPath: "/Users/x")).path,
            "/Users/x/Library/Application Support/Sticky Notes/notes.json"
        )
    }

    func test_userHomeDirectory_isAnExistingDirectory() {
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: StickyStore.userHomeDirectory().path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    func test_widgetDrawn_isNil_untilTheWidgetMarksIt_thenIsWhenItDid() throws {
        XCTAssertNil(store.widgetDrawnDate())

        try store.markWidgetDrawn(at: t0)

        XCTAssertEqual(store.widgetDrawnDate(), t0)
        try store.markWidgetDrawn(at: t0.addingTimeInterval(5))
        XCTAssertEqual(store.widgetDrawnDate(), t0.addingTimeInterval(5))
    }
}
