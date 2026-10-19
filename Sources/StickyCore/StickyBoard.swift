import Foundation

/// One line on the widget. Its button crosses it out; pressing again removes it.
public struct StickyNote: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let isCrossedOut: Bool
    public let createdAt: Date

    public init(id: UUID = UUID(), text: String, isCrossedOut: Bool = false, createdAt: Date) {
        self.id = id
        self.text = text
        self.isCrossedOut = isCrossedOut
        self.createdAt = createdAt
    }
}

/// Every note, newest first. Changes return a new board.
public struct StickyBoard: Codable, Equatable, Sendable {
    /// Plenty for a one-line note; keeps a pasted essay from bloating the file.
    public static let maxTextLength = 280

    public static let empty = StickyBoard(notes: [])

    public let notes: [StickyNote]

    public init(notes: [StickyNote]) { self.notes = notes }

    /// Adds `text` at the top, trimmed and capped. Blank text changes nothing.
    public func adding(_ text: String, now: Date = Date()) -> StickyBoard {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self }
        let note = StickyNote(text: String(trimmed.prefix(Self.maxTextLength)), createdAt: now)
        return StickyBoard(notes: [note] + notes)
    }

    /// The note's button: an open note gets crossed out, a crossed-out note goes away.
    public func pressing(_ id: UUID) -> StickyBoard {
        guard let note = notes.first(where: { $0.id == id }) else { return self }
        if note.isCrossedOut {
            return StickyBoard(notes: notes.filter { $0.id != id })
        }
        let crossed = StickyNote(id: note.id, text: note.text, isCrossedOut: true, createdAt: note.createdAt)
        return StickyBoard(notes: notes.map { $0.id == id ? crossed : $0 })
    }

    /// What fits in `limit` rows: every note if they all fit, otherwise all but the last row,
    /// which then says how many notes did not fit.
    public func visible(limit: Int) -> (notes: [StickyNote], hiddenCount: Int) {
        let rows = notes.count <= limit ? notes.count : max(0, limit - 1)
        let shown = Array(notes.prefix(rows))
        return (shown, notes.count - shown.count)
    }
}
