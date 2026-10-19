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
        NotesListView(entry: entry, limit: family.noteLimit)
    }
}

/// Header with a +, then one note per line. The whole widget opens the add box; each note's
/// circle is its own button.
struct NotesListView: View {
    let entry: NotesEntry
    let limit: Int
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var ink: Color { renderingMode == .fullColor ? StickyPalette.ink : .primary }

    var body: some View {
        let visible = entry.board.visible(limit: limit)
        VStack(alignment: .leading, spacing: 8) {
            header
            if let error = entry.loadError {
                message("Can't read your notes", detail: error)
            } else if visible.notes.isEmpty {
                message("No notes", detail: "Click anywhere to add one")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(visible.notes) { NoteRow(note: $0, ink: ink) }
                    if visible.hiddenCount > 0 {
                        Text("\(visible.hiddenCount) more")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ink.opacity(0.55))
                            .padding(.leading, NoteRow.textInset)
                            .frame(height: NoteRow.height)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .widgetURL(StickyLink.add.url)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Sticky Notes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: "plus")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ink)
                .frame(width: 22, height: 22)
                .background(Circle().fill(ink.opacity(renderingMode == .fullColor ? 0.12 : 0.2)))
                .accessibilityLabel("Add a note")
        }
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

/// Circle, then the note. Crossed-out notes show an x: the next click removes them.
private struct NoteRow: View {
    static let height: CGFloat = 20
    private static let circleSize: CGFloat = 18
    private static let gap: CGFloat = 8
    /// Where the note text starts, so the "N more" row lines up with it.
    static let textInset = circleSize + gap

    let note: StickyNote
    let ink: Color

    var body: some View {
        HStack(spacing: Self.gap) {
            Button(intent: PressNoteIntent(id: note.id)) {
                Image(systemName: note.isCrossedOut ? "xmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(ink.opacity(0.55))
                    .frame(width: Self.circleSize, height: Self.circleSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(note.isCrossedOut ? "Remove \(note.text)" : "Cross out \(note.text)")

            Text(note.text)
                .font(.system(size: 13))
                .strikethrough(note.isCrossedOut)
                .foregroundStyle(note.isCrossedOut ? ink.opacity(0.4) : ink)
                .lineLimit(1)
        }
        .frame(height: Self.height)
    }
}
