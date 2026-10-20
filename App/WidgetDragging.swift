import AppKit
import WidgetKit
import StickyCore
import os

/// Reordering right on the desktop widget. Invisible catchers sit over each note's text; a
/// quick click there edits the note as before, while holding or dragging lifts it, slides the
/// others aside, and drops it into the nearest slot.
@MainActor
final class WidgetDragging {
    /// How often the widget's position and the notes are rechecked.
    private static let refreshInterval: TimeInterval = 0.5
    /// How often WidgetKit is asked whether the widget is still placed.
    private static let placedCheckInterval: TimeInterval = 10
    private static let log = Logger(subsystem: "com.stickynotes.app", category: "WidgetDragging")

    private let tracker: any WidgetLocating
    private let catchers = RowCatchers()
    private let stage = DragStage()
    private let store: StickyStore
    /// A plain click on a note's text: edit note `id`, drawn on line `row`.
    private let onClick: (UUID, Int) -> Void
    /// Whether the left mouse button is down right now (harnesses stand in their own).
    private let isMouseDown: () -> Bool

    private var timers: [Timer] = []
    private var window: DesktopWindow?
    private var board = StickyBoard.empty
    /// The notes file's modification date when `board` was read; nil before the first read.
    private var boardStamp: Date??
    private var press: Press?
    /// Refreshes in a row that found the button up mid-press. One can be a release still on its
    /// way to the catcher, so it takes two to call the press off.
    private var buttonUpReadings = 0

    private struct Press {
        let line: RowCatchers.Line
        let gesture: WidgetPress
        /// The rows as they were when the press began.
        let notes: [StickyNote]
        let isLifted: Bool

        func lifted() -> Press { Press(line: line, gesture: gesture, notes: notes, isLifted: true) }
    }

    init(
        tracker: (any WidgetLocating)? = nil,
        store: StickyStore = StickyStore(),
        isMouseDown: @escaping () -> Bool = { NSEvent.pressedMouseButtons & 1 != 0 },
        onClick: @escaping (UUID, Int) -> Void
    ) {
        self.tracker = tracker ?? WidgetTracker()
        self.store = store
        self.isMouseDown = isMouseDown
        self.onClick = onClick
        catchers.onPress = { [weak self] in self?.pressBegan(on: $0, at: $1, time: $2) }
        catchers.onMove = { [weak self] in self?.pressMoved(to: $0, time: $1) }
        catchers.onRelease = { [weak self] in self?.pressEnded(at: $0, time: $1) }
        // The order may have changed under the stage; put the catchers right straight away.
        stage.onHidden = { [weak self] in self?.refresh() }
    }

    func start() {
        guard timers.isEmpty else { return }
        tracker.checkPlaced()
        refresh()
        timers = [
            Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            },
            Timer.scheduledTimer(withTimeInterval: Self.placedCheckInterval, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tracker.checkPlaced() }
            },
        ]
    }

    /// The widget just opened a link, so it's under the pointer.
    func learnWidgetUnderPointer() {
        tracker.learnFromPointer()
        refresh()
    }

    /// Follows the widget and the notes file. Left alone mid-press and while the stage is up,
    /// so a catcher never moves out from under the pointer.
    private func refresh() {
        if press != nil {
            abandonPressIfMouseIsUp()
            return
        }
        guard !stage.isVisible else { return }
        reloadBoardIfChanged()
        window = tracker.locate()
        guard let window else {
            catchers.hide()
            return
        }
        catchers.show(lines(in: window), level: Self.level(above: window))
    }

    /// A release that never reached the catcher (a system gesture took over mid-drag, say) must
    /// not leave a note lifted forever: once the button is up, the press is called off unsaved.
    private func abandonPressIfMouseIsUp() {
        buttonUpReadings = isMouseDown() ? 0 : buttonUpReadings + 1
        if buttonUpReadings >= 2 { cancelPress() }
    }

    private func cancelPress() {
        guard let cancelled = press else { return }
        press = nil
        buttonUpReadings = 0
        if cancelled.isLifted { stage.drop(into: nil) }
    }

    /// Rereads the notes when the file changed. A file that can't be read is logged once and
    /// left alone until it changes again (the widget shows that error itself).
    private func notesModificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: store.url.path))?[.modificationDate] as? Date
    }

    private func reloadBoardIfChanged() {
        let stamp = notesModificationDate()
        guard boardStamp != .some(stamp) else { return }
        boardStamp = .some(stamp)
        do {
            board = try store.load()
        } catch {
            board = .empty
            Self.log.error("Could not read notes: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func visibleNotes(in window: DesktopWindow) -> [StickyNote] {
        let limit = WidgetLayout.rowLimit(contentHeight: WidgetLayout.contentFrame(ofWindow: window.frame).height)
        return board.visible(limit: limit).notes
    }

    private func lines(in window: DesktopWindow) -> [RowCatchers.Line] {
        visibleNotes(in: window).enumerated().compactMap { row, note in
            WidgetLayout.textFrame(inWindow: window.frame, row: row, isCrossedOut: note.isCrossedOut).map {
                RowCatchers.Line(noteID: note.id, row: row, frame: DesktopWidgetWindows.toScreen($0))
            }
        }
    }

    /// Just above the widget: over it, but under every ordinary window, like the widget itself.
    private static func level(above window: DesktopWindow) -> NSWindow.Level {
        NSWindow.Level(rawValue: window.layer + 1)
    }

    // MARK: - Press, hold, drag, drop

    private func pressBegan(on line: RowCatchers.Line, at point: NSPoint, time: TimeInterval) {
        // An earlier press whose release went missing ends here.
        cancelPress()
        guard !stage.isVisible, let window else { return }
        reloadBoardIfChanged()
        let notes = visibleNotes(in: window)
        guard notes.indices.contains(line.row) else {
            refresh()
            return
        }
        // The press is on whatever note that line shows now, which can differ from when the
        // catchers were last placed (a drop or a circle click since).
        let pressed = RowCatchers.Line(noteID: notes[line.row].id, row: line.row, frame: line.frame)
        let gesture = WidgetPress(start: point, startTime: time)
        press = Press(line: pressed, gesture: gesture, notes: notes, isLifted: false)
        buttonUpReadings = 0
        // Held still: lift once the hold delay passes, without waiting for the pointer to move.
        // A button already up means the release is on its way (a click) or was lost (the
        // refresh calls that off), so no lift then.
        DispatchQueue.main.asyncAfter(deadline: .now() + WidgetPress.holdDelay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, let press = self.press, press.gesture == gesture, !press.isLifted, self.isMouseDown() else { return }
                self.lift()
            }
        }
    }

    private func pressMoved(to point: NSPoint, time: TimeInterval) {
        guard let current = press else { return }
        if !current.isLifted {
            guard current.gesture.isDrag(at: point, time: time) else { return }
            lift()
        }
        // Screen y grows upward; the rows run downward.
        stage.drag(by: current.gesture.start.y - point.y)
    }

    private func pressEnded(at point: NSPoint, time: TimeInterval) {
        guard let ended = press else { return }
        press = nil
        guard ended.isLifted else {
            onClick(ended.line.noteID, ended.line.row)
            return
        }
        drop(ended)
    }

    private func lift() {
        guard let current = press, let window,
              let rows = WidgetLayout.rowsFrame(inWindow: window.frame, rowCount: current.notes.count) else { return }
        press = current.lifted()
        stage.show(notes: current.notes, lifting: current.line.row, frame: DesktopWidgetWindows.toScreen(rows), level: Self.level(above: window))
    }

    private func drop(_ ended: Press) {
        let from = ended.line.row
        guard let target = stage.target, target != from else {
            stage.drop(into: nil)
            return
        }
        do {
            try store.update { $0.moving(ended.line.noteID, to: target) }
            WidgetCenter.shared.reloadAllTimelines()
            // Up until the widget has redrawn from the saved file (it marks the start of each
            // redraw, before it reads), so the old order never flashes back.
            let saved = notesModificationDate() ?? Date()
            stage.drop(into: RowReorder.moved(ended.notes, from: from, to: target)) { [store] in
                (store.widgetDrawnDate() ?? .distantPast) >= saved
            }
        } catch {
            Self.log.error("Could not save the new order: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
            stage.drop(into: nil)
        }
    }
}
