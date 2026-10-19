import SwiftUI
import WidgetKit
import StickyCore

/// Paper and ink for full color. When macOS dims widgets to gray, the system drops the paper
/// and everything draws in `.primary` instead, which stays legible there.
enum StickyPalette {
    static let paper = Color(red: 1.0, green: 0.925, blue: 0.6)
    static let ink = Color(red: 0.25, green: 0.2, blue: 0.06)
}

struct NotesEntryView: View {
    let entry: NotesEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        // Rows from the widget's real height (it varies by display), the same measurement the
        // app makes when it places an edit field. Small widgets can't hold links, so there a
        // note's text is a button that opens the link.
        GeometryReader { geometry in
            NotesListView(
                entry: entry,
                limit: WidgetLayout.rowLimit(contentHeight: geometry.size.height),
                editsViaIntent: family == .systemSmall
            )
        }
    }
}

/// Header with a +, then one note per line. The whole widget opens the box; a note's circle and
/// x are buttons, and its text opens an edit field right over that line. Every size and gap comes
/// from `WidgetLayout`, which the app uses to place that field.
struct NotesListView: View {
    let entry: NotesEntry
    let limit: Int
    let editsViaIntent: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var ink: Color { renderingMode == .fullColor ? StickyPalette.ink : .primary }

    var body: some View {
        let visible = entry.board.visible(limit: limit)
        VStack(alignment: .leading, spacing: WidgetLayout.headerSpacing) {
            header
            if let error = entry.loadError {
                message("Can't read your notes", detail: error)
            } else if visible.notes.isEmpty {
                message("No notes", detail: "Click anywhere to add one")
            } else {
                VStack(alignment: .leading, spacing: WidgetLayout.rowSpacing) {
                    ForEach(Array(visible.notes.enumerated()), id: \.element.id) { row, note in
                        NoteRow(note: note, row: row, ink: ink, editsViaIntent: editsViaIntent)
                    }
                    if visible.hiddenCount > 0 {
                        Text("\(visible.hiddenCount) more")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ink.opacity(0.55))
                            .padding(.leading, WidgetLayout.textInset)
                            .frame(height: WidgetLayout.rowHeight)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(WidgetLayout.padding)
        .widgetURL(StickyLink.add.url)
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
/// an x at the end that deletes it. Clicking the text edits it in place.
private struct NoteRow: View {
    let note: StickyNote
    /// The line it's drawn on, sent with the edit link so the field lands where the user clicked.
    let row: Int
    let ink: Color
    let editsViaIntent: Bool

    var body: some View {
        HStack(spacing: WidgetLayout.gap) {
            Button(intent: ToggleNoteIntent(id: note.id)) {
                Image(systemName: note.isCrossedOut ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(ink.opacity(0.55))
                    .frame(width: WidgetLayout.circleSize, height: WidgetLayout.circleSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(note.isCrossedOut ? "Bring back \(note.text)" : "Cross out \(note.text)")

            editTarget

            if note.isCrossedOut {
                Button(intent: RemoveNoteIntent(id: note.id)) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(ink.opacity(0.6))
                        .frame(width: WidgetLayout.deleteWidth, height: WidgetLayout.rowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(note.text)")
            }
        }
        .frame(height: WidgetLayout.rowHeight)
    }

    @ViewBuilder
    private var editTarget: some View {
        if editsViaIntent {
            Button(intent: EditNoteIntent(id: note.id, row: row)) { noteText }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(note.text)")
        } else {
            Link(destination: StickyLink.edit(note.id, row: row).url) { noteText }
                .accessibilityLabel("Edit \(note.text)")
        }
    }

    private var noteText: some View {
        Text(note.text)
            .font(.system(size: 13))
            .strikethrough(note.isCrossedOut)
            .foregroundStyle(note.isCrossedOut ? ink.opacity(0.4) : ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}
