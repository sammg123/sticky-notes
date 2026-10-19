import Foundation

/// `~/Library/Application Support/Sticky Notes/notes.json`, written atomically. The app adds
/// notes and the sandboxed widget crosses them out, so both read and write this one file.
public struct StickyStore: Sendable {
    public let url: URL

    public init(url: URL = StickyStore.defaultURL()) { self.url = url }

    /// Honors `STICKY_NOTES_PATH` (tests, previews) before Application Support. Built from the
    /// real home directory so the sandboxed widget resolves the same file as the app.
    public static func defaultURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = StickyStore.userHomeDirectory()
    ) -> URL {
        if let override = environment["STICKY_NOTES_PATH"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return home
            .appendingPathComponent("Library/Application Support/Sticky Notes", isDirectory: true)
            .appendingPathComponent("notes.json")
    }

    /// The user's actual home directory, even from inside an app sandbox (where the home
    /// directory APIs point into the container).
    public static func userHomeDirectory() -> URL { realHome }

    // Looked up once: getpwuid hands back a shared buffer that isn't safe to read concurrently.
    private static let realHome: URL = {
        if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }()

    /// Missing file = no notes. A file that no longer decodes is moved aside (kept as
    /// `notes.corrupt-<time>.json`) and the board starts empty, so the widget keeps working.
    public func load() throws -> StickyBoard {
        guard FileManager.default.fileExists(atPath: url.path) else { return .empty }
        let data = try Data(contentsOf: url)
        do {
            return try Self.decoder.decode(StickyBoard.self, from: data)
        } catch let error as DecodingError {
            try setAside(because: error)
            return .empty
        }
    }

    public func save(_ board: StickyBoard) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(board).write(to: url, options: .atomic)
    }

    /// Reads the current file, applies `change`, saves, and returns the result. The app and every
    /// widget press do this, so it holds an exclusive lock on `notes.json.lock` for the whole
    /// read-change-write; without it two quick presses could each overwrite the other's change.
    @discardableResult
    public func update(_ change: (StickyBoard) -> StickyBoard) throws -> StickyBoard {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let lock = open(url.appendingPathExtension("lock").path, O_CREAT | O_RDWR, 0o644)
        guard lock >= 0 else { throw Self.posixError() }
        defer { close(lock) } // closing also releases the lock
        guard flock(lock, LOCK_EX) == 0 else { throw Self.posixError() }
        let next = change(try load())
        try save(next)
        return next
    }

    private func setAside(because error: DecodingError) throws {
        let stamp = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withYear, .withMonth, .withDay, .withTime])
        let name = "\(url.deletingPathExtension().lastPathComponent).corrupt-\(stamp)-\(UUID().uuidString.prefix(4)).json"
        try FileManager.default.moveItem(at: url, to: url.deletingLastPathComponent().appendingPathComponent(name))
        NSLog("Sticky Notes: \(url.lastPathComponent) could not be read (\(error)); moved it to \(name) and started empty")
    }

    private static func posixError() -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
