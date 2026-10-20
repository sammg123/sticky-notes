import AppKit
import StickyCore

/// Where Notification Center draws desktop widgets, read from the window list. Its frames are
/// in points with y growing down from the top of the main display; `toScreen` converts to AppKit.
@MainActor
enum DesktopWidgetWindows {
    private static let ownerBundleID = "com.apple.notificationcenterui"

    enum Lookup {
        case onScreen(DesktopWindow)
        /// Still there but not showing, say while a full-screen app's space is in front.
        case hidden
        case gone
    }

    /// Every widget-sized Notification Center window on screen, front to back.
    static func onScreen() -> [DesktopWindow] {
        let owners = ownerPIDs()
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { window(from: $0, ownedBy: owners) }.filter { WidgetLayout.isWidgetSized($0.frame) }
    }

    /// Window `number`, if Notification Center still has it.
    static func lookup(_ number: Int) -> Lookup {
        let list = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(number)) as? [[String: Any]] ?? []
        guard let info = list.first, let window = window(from: info, ownedBy: ownerPIDs()) else { return .gone }
        return (info[kCGWindowIsOnscreen as String] as? Bool) == true ? .onScreen(window) : .hidden
    }

    /// The window a click at `point` (window list coordinates) would land on, looking past
    /// `skipping` (this app's own windows), or nil if there is none.
    static func frontmostWindowNumber(at point: CGPoint, skipping: Set<Int>) -> Int? {
        let screenPoint = NSPoint(x: point.x, y: mainDisplayHeight - point.y)
        var number = NSWindow.windowNumber(at: screenPoint, belowWindowWithWindowNumber: 0)
        while number != 0, skipping.contains(number) {
            number = NSWindow.windowNumber(at: screenPoint, belowWindowWithWindowNumber: number)
        }
        return number == 0 ? nil : number
    }

    /// The pointer, in window list coordinates.
    static func pointer() -> CGPoint {
        let mouse = NSEvent.mouseLocation
        return CGPoint(x: mouse.x, y: mainDisplayHeight - mouse.y)
    }

    /// A window list rect in AppKit screen coordinates (y up from the bottom of the main display).
    static func toScreen(_ rect: CGRect) -> NSRect {
        NSRect(x: rect.minX, y: mainDisplayHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    private static var mainDisplayHeight: CGFloat { NSScreen.screens.first?.frame.maxY ?? 0 }

    /// Notification Center, looked up again only once it has quit (this runs twice a second).
    private static var owners: [NSRunningApplication] = []

    private static func ownerPIDs() -> Set<pid_t> {
        if owners.isEmpty || owners.allSatisfy(\.isTerminated) {
            owners = NSRunningApplication.runningApplications(withBundleIdentifier: ownerBundleID)
        }
        return Set(owners.filter { !$0.isTerminated }.map(\.processIdentifier))
    }

    private static func window(from info: [String: Any], ownedBy owners: Set<pid_t>) -> DesktopWindow? {
        guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, owners.contains(pid),
              let number = info[kCGWindowNumber as String] as? Int,
              let layer = info[kCGWindowLayer as String] as? Int,
              let bounds = info[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds) else { return nil }
        return DesktopWindow(number: number, frame: frame, layer: layer)
    }
}
