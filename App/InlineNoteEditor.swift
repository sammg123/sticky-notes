import AppKit
import WidgetKit
import StickyCore

/// Edits a note right on the desktop widget: a borderless sticky-yellow field laid exactly over
/// the note's line. Return saves, Escape cancels, and clicking elsewhere saves (as renaming in
/// Finder does).
@MainActor
final class InlineNoteEditor: NSObject, NSWindowDelegate, NSTextFieldDelegate {
    /// How far the field's paper reaches past the widget's text on each side.
    private static let outset = NSSize(width: 5, height: 4)
    /// NSTextField draws its text this far in from its frame.
    private static let textFieldInset: CGFloat = 2
    private static let paper = NSColor(red: 1.0, green: 0.925, blue: 0.6, alpha: 1)
    private static let ink = NSColor(red: 0.25, green: 0.2, blue: 0.06, alpha: 1)

    private var panel: NSPanel?
    private var field: NSTextField?
    private var noteID: UUID?
    private var previousApp: NSRunningApplication?

    /// Opens the field over line `row` (where the widget drew `id`; looked up if not given) of
    /// the widget under the pointer. False when there is no such widget or note, so the caller
    /// can fall back to the box.
    func show(noteID id: UUID, row: Int?) -> Bool {
        guard let board = try? StickyStore().load(),
              let note = board.notes.first(where: { $0.id == id }),
              let screenFrame = Self.lineFrameOnScreen(row: row, noteID: id, board: board) else { return false }
        // Opening over another edit: that edit's app is still the one to go back to.
        let earlier = previousApp
        finish(saving: true, restoringFocus: false)
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? earlier : front
        noteID = id
        let panel = makePanel(frame: screenFrame.insetBy(dx: -Self.outset.width, dy: -Self.outset.height))
        let field = makeField(text: note.text, in: panel)
        self.panel = panel
        self.field = field
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        // Becoming key usually focuses the field already; focusing it again would end that edit.
        if field.currentEditor() == nil { panel.makeFirstResponder(field) }
        // Caret at the end rather than everything selected, so a stray key can't wipe the note.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel === panel else { return }
            if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true); panel.makeKeyAndOrderFront(nil) }
            // Only if it lost focus: focusing a field mid-edit ends that edit (and would save it).
            if field.currentEditor() == nil { panel.makeFirstResponder(field) }
            field.currentEditor()?.selectedRange = NSRange(location: (field.stringValue as NSString).length, length: 0)
        }
        return true
    }

    /// Where the note's text sits on screen (AppKit coordinates): the widget window under the
    /// pointer plus the layout the widget draws with. `row` is the line the widget drew the note
    /// on; without it, the note's place in the file stands in.
    private static func lineFrameOnScreen(row: Int?, noteID id: UUID, board: StickyBoard) -> NSRect? {
        let windows = DesktopWidgetWindows.onScreen()
        guard let window = WidgetLayout.widgetWindow(containing: DesktopWidgetWindows.pointer(), among: windows)?.frame else { return nil }
        let limit = WidgetLayout.rowLimit(contentHeight: WidgetLayout.contentFrame(ofWindow: window).height)
        guard let line = row ?? board.visible(limit: limit).notes.firstIndex(where: { $0.id == id }),
              let note = board.notes.first(where: { $0.id == id }),
              let text = WidgetLayout.textFrame(inWindow: window, row: line, isCrossedOut: note.isCrossedOut) else { return nil }
        return DesktopWidgetWindows.toScreen(text)
    }

    private func makePanel(frame: NSRect) -> NSPanel {
        let panel = EditPanel(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        let paper = NSView(frame: NSRect(origin: .zero, size: frame.size))
        paper.wantsLayer = true
        paper.layer?.backgroundColor = Self.paper.cgColor
        paper.layer?.cornerRadius = 5
        paper.layer?.borderWidth = 1
        paper.layer?.borderColor = Self.ink.withAlphaComponent(0.3).cgColor
        panel.contentView = paper
        return panel
    }

    private func makeField(text: String, in panel: NSPanel) -> NSTextField {
        let field = NSTextField(string: text)
        field.font = .systemFont(ofSize: 13)
        field.textColor = Self.ink
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.delegate = self
        field.setAccessibilityLabel("Edit note")
        let bounds = panel.contentView?.bounds ?? .zero
        let height = field.intrinsicContentSize.height
        // Text starts where the widget's text starts, vertically centered on the line.
        let x = Self.outset.width - Self.textFieldInset
        field.frame = NSRect(x: x, y: ((bounds.height - height) / 2).rounded(), width: bounds.width - 2 * x, height: height)
        panel.contentView?.addSubview(field)
        return field
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            // An emptied note isn't saved (that would wipe it), so say so instead of closing.
            guard !textView.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                NSSound.beep()
                return true
            }
            finish(saving: true, restoringFocus: true)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            finish(saving: false, restoringFocus: true)
            return true
        default:
            return false
        }
    }

    /// Tab or Shift-Tab ends editing without a command we see above: keep what was typed.
    /// (Other endings are focus changes inside AppKit and are not the user leaving the field.)
    func controlTextDidEndEditing(_ notification: Notification) {
        let movement = (notification.userInfo?["NSTextMovement"] as? Int).flatMap(NSTextMovement.init(rawValue:))
        guard movement == .tab || movement == .backtab || movement == .return else { return }
        finish(saving: true, restoringFocus: true)
    }

    /// Clicking anywhere else keeps what was typed. Focus stays wherever that click put it.
    func windowDidResignKey(_ notification: Notification) {
        finish(saving: true, restoringFocus: false)
    }

    /// Closes the field. `restoringFocus` hands the keyboard back to the app that had it before
    /// the edit; only right after Return, Escape or Tab, when nothing else has taken it.
    private func finish(saving: Bool, restoringFocus: Bool) {
        guard let panel, let field, let noteID else { return }
        self.panel = nil
        self.field = nil
        self.noteID = nil
        // The field editor holds what's typed until editing ends; stringValue can still be stale.
        if saving { save(field.currentEditor()?.string ?? field.stringValue, to: noteID) }
        panel.orderOut(nil)
        if restoringFocus { previousApp?.activate() }
        previousApp = nil
    }

    private func save(_ text: String, to id: UUID) {
        do {
            try StickyStore().update { $0.editing(id, text: text) }
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            NSLog("Sticky Notes: could not save an edit: \(error.localizedDescription)")
            NSSound.beep()
        }
    }
}

/// Borderless panels only take the keyboard if they say so.
private final class EditPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
