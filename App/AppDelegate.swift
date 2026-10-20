import AppKit
import StickyCore

/// A background app (no Dock icon, no windows) that does what the widget can't: shows the box
/// its `stickynotes://add` link opens, lays the edit field `stickynotes://edit/<id>` asks for
/// over a note's line, and lets notes be dragged into order on the widget itself.
/// Opening the app directly shows the box too.
@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let addPanel = FloatingInputPanel()
    private let inlineEditor = InlineNoteEditor()
    private lazy var widgetDragging = WidgetDragging { [weak self] id, row in self?.edit(id, row: row) }

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        // `delegate` is weak on NSApplication; this keeps ours alive for the life of the app.
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.editMenuBar()
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    /// Opened by hand (Finder, Spotlight) rather than by the widget's link: show the box.
    func applicationDidFinishLaunching(_ notification: Notification) {
        widgetDragging.start()
        LoginItem.registerOnce()
        let isDefaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == true
        if isDefaultLaunch && !Self.launchedInBackground { showAddBox() }
    }

    /// Started at login, or by the installer with `--background`: stay out of sight.
    private static var launchedInBackground: Bool {
        if CommandLine.arguments.contains("--background") { return true }
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    /// Opened by hand again while it is already running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showAddBox()
        return false
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: text),
              let link = StickyLink(url: url) else {
            NSLog("Sticky Notes: ignoring a link it does not handle")
            return
        }
        // A click on the widget opened this, so the widget is under the pointer.
        if StickyLink.cameFromWidget(url) { widgetDragging.learnWidgetUnderPointer() }
        switch link {
        case .add:
            showAddBox()
        case .edit(let id, let row):
            edit(id, row: row)
        }
    }

    /// Over the note's line on the widget; if that can't be found, in the box.
    private func edit(_ id: UUID, row: Int?) {
        if !inlineEditor.show(noteID: id, row: row) {
            addPanel.show { close in AddNoteView(onClose: close, editing: id) }
        }
    }

    private func showAddBox() {
        addPanel.show { close in AddNoteView(onClose: close) }
    }

    /// Never shown (the app has no menu bar of its own), but text fields only get Cut, Copy,
    /// Paste, Select All and Undo through these key equivalents.
    private static func editMenuBar() -> NSMenu {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = edit
        let bar = NSMenu()
        bar.addItem(NSMenuItem())
        bar.addItem(editItem)
        return bar
    }
}
