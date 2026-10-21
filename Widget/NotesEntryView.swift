import SwiftUI
import WidgetKit
import StickyCore

struct NotesEntryView: View {
    let entry: NotesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        // Rows from the widget's real size (it varies by display), the same measurement the
        // app makes when it places an edit field. Small widgets can't hold links, so there a
        // note's text is a button that opens the link.
        GeometryReader { geometry in
            NotesListView(
                entry: entry,
                layout: WidgetLayout.rows(entry.board.notes, contentSize: geometry.size),
                editsViaIntent: family == .systemSmall
            )
        }
    }
}

/// Header with a +, then the notes, each wrapped to up to three lines. The whole widget opens the box; a note's circle and
/// x are buttons, and its text opens an edit field right over that line. Every size and gap comes
/// from `WidgetLayout`, which the app uses to place that field.
struct NotesListView: View {
    let entry: NotesEntry
    let layout: WidgetLayout.Rows
    let editsViaIntent: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var ink: Color { renderingMode == .fullColor ? StickyPalette.ink : .primary }

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetLayout.headerSpacing) {
            header
            if let error = entry.loadError {
                message("Can't read your notes", detail: error)
            } else if entry.board.notes.isEmpty {
                message("No notes", detail: "Click anywhere to add one")
            } else {
                VStack(alignment: .leading, spacing: WidgetLayout.rowSpacing) {
                    ForEach(Array(layout.rows.enumerated()), id: \.element.note.id) { index, row in
                        NoteRow(note: row.note, row: index, lines: row.lines, ink: ink, editsViaIntent: editsViaIntent)
                    }
                    if layout.hiddenCount > 0 {
                        Text("\(layout.hiddenCount) more")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ink.opacity(0.55))
                            .padding(.leading, WidgetLayout.textInset)
                            .frame(height: WidgetLayout.firstLineHeight)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(WidgetLayout.padding)
        .widgetURL(StickyLink.add.widgetURL)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Notes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ink)
                .frame(width: WidgetLayout.headerHeight, height: WidgetLayout.headerHeight)
                .background(Circle().fill(ink.opacity(renderingMode == .fullColor ? 0.12 : 0.2)))
                .accessibilityLabel("Add a note")
        }
        .frame(height: WidgetLayout.headerHeight)
    }

    private func message(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ink.opacity(0.75))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(ink.opacity(0.55))
                .lineLimit(2)
        }
    }
}

/// Circle, then the note. The circle crosses a note out and back; a crossed-out note also gets
/// an x at the end that deletes it. Clicking the text edits it in place. (While the app is
/// running it catches presses on the text itself, so it can tell a click from a drag.)
private struct NoteRow: View {
    let note: StickyNote
    /// The row it's drawn on, sent with the edit link so the field lands where the user clicked.
    let row: Int
    let lines: Int
    let ink: Color
    let editsViaIntent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: WidgetLayout.gap) {
            Button(intent: ToggleNoteIntent(id: note.id)) { NoteCircleMark(note: note, ink: ink) }
                .buttonStyle(.plain)
                .accessibilityLabel(note.isCrossedOut ? "Bring back \(note.text)" : "Cross out \(note.text)")

            editTarget

            if note.isCrossedOut {
                Button(intent: RemoveNoteIntent(id: note.id)) { NoteDeleteMark(ink: ink) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete \(note.text)")
            }
        }
        .frame(height: WidgetLayout.rowHeight(lines: lines))
    }

    @ViewBuilder
    private var editTarget: some View {
        if editsViaIntent {
            Button(intent: EditNoteIntent(id: note.id, row: row)) { noteText }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(note.text)")
        } else {
            Link(destination: StickyLink.edit(note.id, row: row).widgetURL) { noteText }
                .accessibilityLabel("Edit \(note.text)")
        }
    }

    private var noteText: some View { NoteTextLabel(note: note, lines: lines, ink: ink) }
}
