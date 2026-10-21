import CoreGraphics

/// The widget's layout in points, shared by the widget (to draw) and the app (to put the edit
/// field exactly over a note's line). The widget turns off the system content margins and pads
/// itself by `padding`, so these numbers are the whole story.
public enum WidgetLayout {
    public static let padding: CGFloat = 16
    public static let headerHeight: CGFloat = 22
    public static let headerSpacing: CGFloat = 8
    /// A row's first line: a line of text with 2pt above and below. The circle and x sit on it.
    public static let firstLineHeight: CGFloat = 20
    /// Each further line of a note that wraps.
    public static let lineHeight = NoteText.lineHeight
    public static let rowSpacing: CGFloat = 4
    public static let circleSize: CGFloat = 18
    public static let gap: CGFloat = 8
    public static let deleteWidth: CGFloat = 20
    /// Where a note's text starts, measured from the padding edge.
    public static let textInset = circleSize + gap
    /// Desktop widget windows extend this far past the widget on every side (its shadow).
    public static let windowInset: CGFloat = 8
    /// How far the area redrawn during a drag reaches past the rows, so a lifted row's backing
    /// and shadow have room without touching the header or the widget's rounded corners.
    public static let stageMargin = CGSize(width: 6, height: 4)

    /// One note on the widget: how many lines it wraps to and where its row starts.
    public struct Row: Equatable, Sendable {
        public let note: StickyNote
        public let lines: Int
        /// From the top of the first row, y down.
        public let top: CGFloat

        public init(note: StickyNote, lines: Int, top: CGFloat) {
            self.note = note
            self.lines = lines
            self.top = top
        }

        public var height: CGFloat { WidgetLayout.rowHeight(lines: lines) }
    }

    /// The rows the widget shows, and how many notes didn't fit (the last row then says so).
    public struct Rows: Equatable, Sendable {
        public let rows: [Row]
        public let hiddenCount: Int
    }

    public static func rowHeight(lines: Int) -> CGFloat {
        firstLineHeight + CGFloat(max(lines, 1) - 1) * lineHeight
    }

    /// How wide a note's text is: the row less the circle, and less the x once crossed out.
    public static func textWidth(contentWidth: CGFloat, isCrossedOut: Bool) -> CGFloat {
        contentWidth - 2 * padding - textInset - (isCrossedOut ? gap + deleteWidth : 0)
    }

    /// The notes that fit whole under the header of a widget this size, each wrapped to every
    /// line it needs. When they don't all fit, the last row is left for "N more". Only a first
    /// note taller than the whole widget is cut short, to the room there is. `lineCount` is how
    /// many lines a text takes at a width (tests stand in their own).
    public static func rows(
        _ notes: [StickyNote],
        contentSize: CGSize,
        lineCount: (String, CGFloat) -> Int = NoteText.lineCount
    ) -> Rows {
        let room = contentSize.height - 2 * padding - headerHeight - headerSpacing
        var shown: [Row] = []
        for (index, note) in notes.enumerated() {
            let top = shown.last.map { $0.top + $0.height + rowSpacing } ?? 0
            // Every note but the last leaves room under it for at least "N more", since a note
            // that doesn't leaves no room for any note after it either.
            let isLast = index == notes.count - 1
            let usable = room - top - (isLast ? 0 : rowSpacing + firstLineHeight)
            let width = textWidth(contentWidth: contentSize.width, isCrossedOut: note.isCrossedOut)
            let wanted = max(lineCount(note.text, width), 1)
            guard rowHeight(lines: wanted) <= usable else {
                if shown.isEmpty, let room = (1..<wanted).reversed().first(where: { rowHeight(lines: $0) <= usable }) {
                    shown.append(Row(note: note, lines: room, top: top))
                }
                break
            }
            shown.append(Row(note: note, lines: wanted, top: top))
        }
        return Rows(rows: shown, hiddenCount: notes.count - shown.count)
    }

    /// Widget sides vary by display (164/344pt here, 170/364/382pt on larger screens), so any
    /// side in this range counts; everything else about a line's position is measured.
    public static let plausibleSides: ClosedRange<CGFloat> = 120...480

    /// The desktop widget window under `point`, from the window frames macOS reports, skipping
    /// anything that isn't widget-sized. The smallest wins if several overlap.
    public static func widgetWindow(containing point: CGPoint, among windows: [CGRect]) -> CGRect? {
        widgetWindow(containing: point, among: windows.map { DesktopWindow(number: 0, frame: $0, layer: 0) })?.frame
    }

    /// The same, keeping which window it is.
    public static func widgetWindow(containing point: CGPoint, among windows: [DesktopWindow]) -> DesktopWindow? {
        windows
            .filter { $0.frame.contains(point) && isWidgetSized($0.frame) }
            .min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
    }

    public static func isWidgetSized(_ window: CGRect) -> Bool {
        plausibleSides.contains(window.width - 2 * windowInset) && plausibleSides.contains(window.height - 2 * windowInset)
    }

    /// The widget itself, inside its desktop window.
    public static func contentFrame(ofWindow window: CGRect) -> CGRect {
        window.insetBy(dx: windowInset, dy: windowInset)
    }

    /// Where a row's text is drawn, every line of it, in the window's coordinate system with
    /// y growing down (as CGWindowList reports it).
    public static func textFrame(inWindow window: CGRect, row: Row) -> CGRect {
        let content = contentFrame(ofWindow: window)
        return CGRect(
            x: content.minX + padding + textInset,
            y: rowsTop(in: content) + row.top,
            width: textWidth(contentWidth: content.width, isCrossedOut: row.note.isCrossedOut),
            height: row.height
        )
    }

    /// `rows` and `stageMargin` around them (window coordinates, y down): the area the app
    /// redraws over the widget while a note is dragged. Nil for no rows.
    public static func rowsFrame(inWindow window: CGRect, rows: [Row]) -> CGRect? {
        guard let first = rows.first, let last = rows.last else { return nil }
        let content = contentFrame(ofWindow: window)
        let frame = CGRect(
            x: content.minX + padding,
            y: rowsTop(in: content) + first.top,
            width: content.width - 2 * padding,
            height: last.top + last.height - first.top
        )
        return frame.insetBy(dx: -stageMargin.width, dy: -stageMargin.height)
    }

    /// Where the first row starts, under the header.
    private static func rowsTop(in content: CGRect) -> CGFloat {
        content.minY + padding + headerHeight + headerSpacing
    }
}
