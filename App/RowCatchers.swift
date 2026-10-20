import AppKit

/// Invisible panels over each note's text on the desktop widget, one per line, sitting just
/// above the widget in the window stack. They take presses on the text so the app can tell a
/// click (edit the note) from a press-and-drag (reorder it), which the widget itself can't.
/// The circles, x's and + are left uncovered and stay the widget's own.
@MainActor
final class RowCatchers {
    struct Line: Equatable {
        let noteID: UUID
        let row: Int
        /// Screen coordinates.
        let frame: NSRect
    }

    /// Mouse down, dragged and up on a line, with the pointer in screen coordinates and the
    /// event's timestamp.
    var onPress: ((Line, NSPoint, TimeInterval) -> Void)?
    var onMove: ((NSPoint, TimeInterval) -> Void)?
    var onRelease: ((NSPoint, TimeInterval) -> Void)?

    /// How long the catchers stand aside after a right-click, so the next one reaches the
    /// widget's own menu (Edit Widget, Remove Widget).
    private static let standAside: TimeInterval = 3

    private var panels: [CatcherPanel] = []
    private var shown: (lines: [Line], level: NSWindow.Level)?
    private var standAsideUntil = Date.distantPast

    func show(_ lines: [Line], level: NSWindow.Level) {
        guard shown?.lines != lines || shown?.level != level else { return }
        shown = (lines, level)
        while panels.count < lines.count { panels.append(makePanel()) }
        let isStandingAside = Date() < standAsideUntil
        for (panel, line) in zip(panels, lines) {
            panel.catcher.line = line
            panel.ignoresMouseEvents = isStandingAside
            panel.level = level
            panel.setFrame(line.frame, display: false)
            panel.orderFrontRegardless()
        }
        for panel in panels.dropFirst(lines.count) { panel.orderOut(nil) }
    }

    func hide() {
        guard shown != nil else { return }
        shown = nil
        for panel in panels { panel.orderOut(nil) }
    }

    private func makePanel() -> CatcherPanel {
        let panel = CatcherPanel()
        panel.catcher.onDown = { [weak self] line, event in
            self?.onPress?(line, Self.screenPoint(of: event), event.timestamp)
        }
        panel.catcher.onDragged = { [weak self] event in self?.onMove?(Self.screenPoint(of: event), event.timestamp) }
        panel.catcher.onUp = { [weak self] event in self?.onRelease?(Self.screenPoint(of: event), event.timestamp) }
        panel.catcher.onSecondaryClick = { [weak self] in self?.letSecondaryClicksThrough() }
        return panel
    }

    /// The right-click that got here is lost to the widget; the next one, shortly after, isn't.
    private func letSecondaryClicksThrough() {
        standAsideUntil = Date().addingTimeInterval(Self.standAside)
        for panel in panels { panel.ignoresMouseEvents = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.standAside) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, Date() >= self.standAsideUntil else { return }
                for panel in self.panels { panel.ignoresMouseEvents = false }
            }
        }
    }

    private static func screenPoint(of event: NSEvent) -> NSPoint {
        event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
    }
}

/// A borderless panel that never takes the keyboard or brings the app forward, stays put on
/// every Space like the desktop, and catches clicks although nothing in it is visible.
private final class CatcherPanel: NSPanel {
    let catcher = CatcherView()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        // Nearly clear rather than clear: a fully transparent window lets clicks fall through.
        backgroundColor = NSColor(white: 1, alpha: 0.01)
        ignoresMouseEvents = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        contentView = catcher
        setAccessibilityElement(false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class CatcherView: NSView {
    var line: RowCatchers.Line?
    var onDown: ((RowCatchers.Line, NSEvent) -> Void)?
    var onDragged: ((NSEvent) -> Void)?
    var onUp: ((NSEvent) -> Void)?
    var onSecondaryClick: (() -> Void)?
    /// A Control-click is a right-click: its drags and release aren't a note's.
    private var isControlClick = false

    // The app is usually in the background; the first click must count, not just focus it.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        isControlClick = event.modifierFlags.contains(.control)
        guard !isControlClick else {
            onSecondaryClick?()
            return
        }
        guard let line else { return }
        onDown?(line, event)
    }

    override func rightMouseDown(with event: NSEvent) { onSecondaryClick?() }

    override func mouseDragged(with event: NSEvent) {
        guard !isControlClick else { return }
        onDragged?(event)
    }

    override func mouseUp(with event: NSEvent) {
        guard !isControlClick else {
            isControlClick = false
            return
        }
        onUp?(event)
    }
}
