import Foundation

/// One note on the widget. Its circle crosses it out and back; a crossed-out note also gets a
/// button that removes it.
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
    /// Plenty for a note; keeps a pasted essay from bloating the file.
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

    /// The note's circle: crosses an open note out, and brings a crossed-out note back. Either way
    /// the note lands just below the last open note, so a crossed-out note heads the crossed-out
    /// ones and a note brought back ends the open ones. An unknown id changes nothing.
    public func toggling(_ id: UUID) -> StickyBoard {
        guard let note = notes.first(where: { $0.id == id }) else { return self }
        let flipped = StickyNote(id: note.id, text: note.text, isCrossedOut: !note.isCrossedOut, createdAt: note.createdAt)
        let rest = notes.filter { $0.id != id }
        let slot = rest.lastIndex(where: { !$0.isCrossedOut }).map { $0 + 1 } ?? 0
        return StickyBoard(notes: Array(rest[..<slot]) + [flipped] + Array(rest[slot...]))
    }

    /// Replaces the note's text (trimmed and capped), keeping its place and crossed-out state.
    /// Blank text changes nothing, so an emptied field can't wipe a note.
    public func editing(_ id: UUID, text: String) -> StickyBoard {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self }
        let capped = String(trimmed.prefix(Self.maxTextLength))
        return StickyBoard(notes: notes.map { note in
            guard note.id == id else { return note }
            return StickyNote(id: note.id, text: capped, isCrossedOut: note.isCrossedOut, createdAt: note.createdAt)
        })
    }

    /// Deletes the note.
    public func removing(_ id: UUID) -> StickyBoard {
        StickyBoard(notes: notes.filter { $0.id != id })
    }

    /// Puts the notes in the order of `ids` (from a drag in the list). Notes missing from `ids`
    /// were added since the list was shown, so they stay on top; unknown and repeated ids are skipped.
    public func ordering(_ ids: [UUID]) -> StickyBoard {
        var seen = Set<UUID>()
        let wanted = ids.filter { seen.insert($0).inserted }
        let byID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        let placed = wanted.compactMap { byID[$0] }
        let placedIDs = Set(placed.map(\.id))
        return StickyBoard(notes: notes.filter { !placedIDs.contains($0.id) } + placed)
    }

    /// Moves the note to place `index` (kept inside the list), as a drag on the widget does.
    /// An unknown id changes nothing.
    public func moving(_ id: UUID, to index: Int) -> StickyBoard {
        guard let from = notes.firstIndex(where: { $0.id == id }) else { return self }
        return StickyBoard(notes: RowReorder.moved(notes, from: from, to: min(max(index, 0), notes.count - 1)))
    }
}
