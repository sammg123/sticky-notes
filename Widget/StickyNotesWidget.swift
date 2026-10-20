import SwiftUI
import WidgetKit
import StickyCore
import os

@main
struct StickyNotesWidget: Widget {
    nonisolated static let kind = "StickyNotes"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NotesProvider()) { entry in
            NotesEntryView(entry: entry)
                .containerBackground(for: .widget) { StickyPalette.paper }
        }
        .configurationDisplayName("Notes")
        .description("Click to add a note. Click a note's circle to cross it out, its text to edit it.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // The view pads itself by WidgetLayout.padding, so the app knows exactly where each line is.
        .contentMarginsDisabled()
    }
}

struct NotesEntry: TimelineEntry {
    let date: Date
    let board: StickyBoard
    /// Set when the notes file exists but could not be read.
    let loadError: String?

    /// Gallery preview content, used only when there are no real notes yet.
    static func sample(at date: Date) -> NotesEntry {
        let board = StickyBoard.empty
            .adding("Call the dentist", now: date)
            .adding("Pick up dry cleaning", now: date)
            .adding("Email Prof. Lee", now: date)
        return NotesEntry(date: date, board: board.toggling(board.notes[2].id), loadError: nil)
    }
}

struct NotesProvider: TimelineProvider {
    private static let log = Logger(subsystem: "com.stickynotes.app.widget", category: "Provider")

    func placeholder(in context: Context) -> NotesEntry {
        .sample(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (NotesEntry) -> Void) {
        let entry = load(at: Date())
        completion(context.isPreview && entry.board.notes.isEmpty ? .sample(at: entry.date) : entry)
    }

    /// The app reloads the widget after an add and the circle's intent after a press. The hourly
    /// refresh only catches a reload that got lost (say, while the widget service restarted).
    func getTimeline(in context: Context, completion: @escaping (Timeline<NotesEntry>) -> Void) {
        let now = Date()
        let entry = load(at: now)
        // Tells the app (holding its drag preview over the widget) that this redraw has started.
        do {
            try StickyStore().markWidgetDrawn(at: now)
        } catch {
            Self.log.error("Could not mark the redraw: \(error.localizedDescription, privacy: .public)")
        }
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(Self.safetyRefresh))))
    }

    private static let safetyRefresh: TimeInterval = 60 * 60

    private func load(at date: Date) -> NotesEntry {
        do {
            return NotesEntry(date: date, board: try StickyStore().load(), loadError: nil)
        } catch {
            Self.log.error("Could not read notes: \(error.localizedDescription, privacy: .public)")
            return NotesEntry(date: date, board: .empty, loadError: error.localizedDescription)
        }
    }
}

