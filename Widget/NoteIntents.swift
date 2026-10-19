import AppIntents
import AppKit
import WidgetKit
import StickyCore

/// A note's circle: crosses it out, or brings a crossed-out note back. Runs in the widget
/// process and writes the notes file directly, so it works whether or not the app is running.
struct ToggleNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Cross Out or Restore Sticky Note"
    static let isDiscoverable = false

    @Parameter(title: "Note")
    var noteID: String

    init() {}

    init(id: UUID) {
        noteID = id.uuidString
    }

    func perform() async throws -> some IntentResult {
        try NoteChange.apply(to: noteID) { board, id in board.toggling(id) }
        return .result()
    }
}

/// The x on a crossed-out note: deletes it.
struct RemoveNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Remove Sticky Note"
    static let isDiscoverable = false

    @Parameter(title: "Note")
    var noteID: String

    init() {}

    init(id: UUID) {
        noteID = id.uuidString
    }

    func perform() async throws -> some IntentResult {
        try NoteChange.apply(to: noteID) { board, id in board.removing(id) }
        return .result()
    }
}

/// A note's text on the small widget, which can't hold links: opens the same edit link the
/// larger sizes use, from the widget's own process.
struct EditNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Edit Sticky Note"
    static let isDiscoverable = false

    @Parameter(title: "Note")
    var noteID: String

    @Parameter(title: "Line")
    var row: Int

    init() {}

    init(id: UUID, row: Int) {
        noteID = id.uuidString
        self.row = row
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: noteID) else { throw NoteChangeError.invalidID(noteID) }
        guard NSWorkspace.shared.open(StickyLink.edit(id, row: row).url) else { throw NoteChangeError.couldNotOpenEditor }
        return .result()
    }
}

/// Shared by the circle and the x: validate the id, change the file, redraw the widget.
enum NoteChange {
    static func apply(to noteID: String, _ change: (StickyBoard, UUID) -> StickyBoard) throws {
        guard let id = UUID(uuidString: noteID) else { throw NoteChangeError.invalidID(noteID) }
        do {
            try StickyStore().update { change($0, id) }
        } catch {
            throw NoteChangeError.storage(error.localizedDescription)
        }
        // WidgetKit normally redraws after a widget's own button runs; asking makes sure.
        WidgetCenter.shared.reloadTimelines(ofKind: StickyNotesWidget.kind)
    }
}

enum NoteChangeError: Error, CustomLocalizedStringResourceConvertible {
    case invalidID(String)
    case storage(String)
    case couldNotOpenEditor

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidID(let id): return "No sticky note with id \(id)."
        case .storage(let message): return "Couldn't update your notes: \(message)"
        case .couldNotOpenEditor: return "Couldn't open Sticky Notes to edit the note."
        }
    }
}
