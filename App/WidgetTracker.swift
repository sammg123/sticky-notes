import AppKit
import WidgetKit
import StickyCore
import os

/// Finds the desktop widget; `WidgetTracker` does it for real, harnesses stand in a fixed window.
@MainActor
protocol WidgetLocating: AnyObject {
    /// Where the widget is now, or nil while it isn't showing.
    func locate() -> DesktopWindow?
    /// The widget under the pointer is ours: call when one of its links arrives.
    func learnFromPointer()
    /// Rechecks whether a Sticky Notes widget is placed at all.
    func checkPlaced()
}

/// Knows which desktop window is this app's widget. macOS doesn't say, so the app learns it
/// whenever the widget opens one of its links (the pointer is over the widget then), remembers
/// it across launches, and follows it as it moves or hides. The widget gets a different window
/// for each display arrangement, so the last few are kept.
@MainActor
final class WidgetTracker: WidgetLocating {
    private static let defaultsKey = "widgetWindows"
    private static let log = Logger(subsystem: "com.stickynotes.app", category: "WidgetTracker")

    private let defaults: UserDefaults
    /// The widget's windows as last seen, most recent first.
    private var known: [DesktopWindow]
    /// Whether a Sticky Notes widget is placed at all, checked before trusting a window that only
    /// matches by position (it could be another widget put where ours used to be).
    private var isPlaced = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        known = defaults.data(forKey: Self.defaultsKey).flatMap { try? JSONDecoder().decode([DesktopWindow].self, from: $0) } ?? []
    }

    func learnFromPointer() {
        let pointer = DesktopWidgetWindows.pointer()
        let ownWindows = Set(NSApp.windows.map(\.windowNumber))
        // Only the window a click there would really land on: a link opened from a browser
        // window lying over some other widget must not teach the app that widget.
        guard let front = DesktopWidgetWindows.frontmostWindowNumber(at: pointer, skipping: ownWindows),
              let window = DesktopWidgetWindows.onScreen().first(where: { $0.number == front && $0.frame.contains(pointer) }) else {
            Self.log.info("A widget link arrived, but no widget is under the pointer")
            return
        }
        isPlaced = true
        remember(window)
    }

    func locate() -> DesktopWindow? {
        for (index, window) in known.enumerated() {
            switch DesktopWidgetWindows.lookup(window.number) {
            case .onScreen(let current):
                remember(current)
                return current
            case .hidden:
                continue
            case .gone:
                // The widget service drew it again in a new window (after a restart, say), in the
                // same place. Only trusted for the latest window: an old one's spot may well hold
                // some other widget by now.
                guard index == 0, isPlaced,
                      let redrawn = DesktopWindow.current(window, among: DesktopWidgetWindows.onScreen()) else { continue }
                remember(redrawn)
                return redrawn
            }
        }
        return nil
    }

    /// Asks WidgetKit whether a Sticky Notes widget is placed anywhere.
    func checkPlaced() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            DispatchQueue.main.async { [weak self] in
                switch result {
                case .success(let widgets):
                    self?.isPlaced = !widgets.isEmpty
                case .failure(let error):
                    Self.log.error("Could not list placed widgets: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func remember(_ window: DesktopWindow) {
        guard known.first != window else { return }
        known = DesktopWindow.remembering(window, in: known)
        Self.log.info("Widget window \(window.number, privacy: .public) at \(String(describing: window.frame), privacy: .public)")
        do {
            defaults.set(try JSONEncoder().encode(known), forKey: Self.defaultsKey)
        } catch {
            Self.log.error("Could not remember the widget window: \(error.localizedDescription, privacy: .public)")
        }
    }
}
