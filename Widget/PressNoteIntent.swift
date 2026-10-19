import AppIntents
import WidgetKit
import StickyCore

/// A note's circle. Runs in the widget process and writes the notes file directly, so it works
/// whether or not the app is running.
struct PressNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Cross Out Sticky Note"
    static let isDiscoverable = false

    @Parameter(title: "Note")
    var noteID: String

    init() {}

    init(id: UUID) {
        noteID = id.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: noteID) else { throw PressNoteError.invalidID(noteID) }
        do {
            try StickyStore().update { $0.pressing(id) }
        } catch {
            throw PressNoteError.storage(error.localizedDescription)
        }
        // WidgetKit normally redraws after a widget's own button runs; asking makes sure.
        WidgetCenter.shared.reloadTimelines(ofKind: StickyNotesWidget.kind)
        return .result()
    }
}

enum PressNoteError: Error, CustomLocalizedStringResourceConvertible {
    case invalidID(String)
    case storage(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidID(let id): return "No sticky note with id \(id)."
        case .storage(let message): return "Couldn't update your notes: \(message)"
        }
    }
}
