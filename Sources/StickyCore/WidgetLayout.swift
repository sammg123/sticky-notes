import CoreGraphics

/// The widget's layout in points, shared by the widget (to draw) and the app (to put the edit
/// field exactly over a note's line). The widget turns off the system content margins and pads
/// itself by `padding`, so these numbers are the whole story.
public enum WidgetLayout {
    public static let padding: CGFloat = 16
    public static let headerHeight: CGFloat = 22
    public static let headerSpacing: CGFloat = 8
    public static let rowHeight: CGFloat = 20
    public static let rowSpacing: CGFloat = 4
    public static let circleSize: CGFloat = 18
    public static let gap: CGFloat = 8
    public static let deleteWidth: CGFloat = 20
    /// Where a note's text starts, measured from the padding edge.
    public static let textInset = circleSize + gap
    /// Desktop widget windows extend this far past the widget on every side (its shadow).
    public static let windowInset: CGFloat = 8
    /// From one row's top to the next.
    public static let rowPitch = rowHeight + rowSpacing
    /// How far the area redrawn during a drag reaches past the rows, so a lifted row's backing
    /// and shadow have room without touching the header or the widget's rounded corners.
    public static let stageMargin = CGSize(width: 6, height: 4)

    /// One-line rows that fit under the header in a widget this tall.
    public static func rowLimit(contentHeight: CGFloat) -> Int {
        let room = contentHeight - 2 * padding - headerHeight - headerSpacing + rowSpacing
        return max(0, Int((room / rowPitch).rounded(.down)))
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

    /// Where row `row`'s text is drawn, in the window's coordinate system with y growing down
    /// (as CGWindowList reports it). Nil for a row the widget has no room to show.
    public static func textFrame(inWindow window: CGRect, row: Int, isCrossedOut: Bool) -> CGRect? {
        let content = contentFrame(ofWindow: window)
        guard row >= 0, row < rowLimit(contentHeight: content.height) else { return nil }
        let x = content.minX + padding + textInset
        let y = content.minY + padding + headerHeight + headerSpacing + CGFloat(row) * rowPitch
        let trailing = padding + (isCrossedOut ? gap + deleteWidth : 0)
        return CGRect(x: x, y: y, width: content.maxX - trailing - x, height: rowHeight)
    }

    /// The first `rowCount` rows and `stageMargin` around them (window coordinates, y down): the
    /// area the app redraws over the widget while a note is dragged. Nil for no rows, or more
    /// rows than the widget shows.
    public static func rowsFrame(inWindow window: CGRect, rowCount: Int) -> CGRect? {
        let content = contentFrame(ofWindow: window)
        guard rowCount > 0, rowCount <= rowLimit(contentHeight: content.height) else { return nil }
        let rows = CGRect(
            x: content.minX + padding,
            y: content.minY + padding + headerHeight + headerSpacing,
            width: content.width - 2 * padding,
            height: CGFloat(rowCount) * rowPitch - rowSpacing
        )
        return rows.insetBy(dx: -stageMargin.width, dy: -stageMargin.height)
    }
}
