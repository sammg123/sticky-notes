import SwiftUI
import StickyCore

/// Paper and ink for full color. When macOS dims widgets to gray, the system drops the paper
/// and everything draws in `.primary` instead, which stays legible there.
enum StickyPalette {
    static let paper = Color(red: 1.0, green: 0.925, blue: 0.6)
    static let ink = Color(red: 0.25, green: 0.2, blue: 0.06)
}

// The pieces of a note's line. The widget wraps them in buttons and links; the app draws the
// same pieces over the widget while a note is dragged, so the two can't drift apart.

/// The circle that crosses a note out (a checkmark once it is).
struct NoteCircleMark: View {
    let note: StickyNote
    let ink: Color

    var body: some View {
        Image(systemName: note.isCrossedOut ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 14))
            .foregroundStyle(ink.opacity(0.55))
            .frame(width: WidgetLayout.circleSize, height: WidgetLayout.circleSize)
            // Centered on the note's first line, however many lines the note wraps to.
            .frame(height: WidgetLayout.firstLineHeight)
            .contentShape(Rectangle())
    }
}

/// The note's text, wrapped to the lines its row has, struck through and faded once crossed out.
struct NoteTextLabel: View {
    let note: StickyNote
    /// From `WidgetLayout.rows`, which the app's overlays are placed by too.
    let lines: Int
    let ink: Color

    var body: some View {
        Text(note.text)
            .font(.system(size: NoteText.fontSize))
            .strikethrough(note.isCrossedOut)
            .foregroundStyle(note.isCrossedOut ? ink.opacity(0.4) : ink)
            .lineLimit(lines)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: WidgetLayout.rowHeight(lines: lines))
            .contentShape(Rectangle())
    }
}

/// The x a crossed-out note gets, which deletes it.
struct NoteDeleteMark: View {
    let ink: Color

    var body: some View {
        Image(systemName: "xmark")
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(ink.opacity(0.6))
            .frame(width: WidgetLayout.deleteWidth, height: WidgetLayout.firstLineHeight)
            .contentShape(Rectangle())
    }
}
