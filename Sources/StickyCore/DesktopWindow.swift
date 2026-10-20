import CoreGraphics

/// A window as the window list reports it: frame in screen points with y growing down from the
/// top of the main display, and its level. Desktop widgets are each drawn in one of these.
public struct DesktopWindow: Codable, Equatable, Sendable {
    public let number: Int
    public let frame: CGRect
    public let layer: Int

    public init(number: Int, frame: CGRect, layer: Int) {
        self.number = number
        self.frame = frame
        self.layer = layer
    }

    /// Where the widget last seen in `last` is now: the same window if it's still on screen
    /// (it may have been moved), otherwise one exactly where it was (the widget service drew it
    /// again in a new window). Nil if neither is on screen.
    public static func current(_ last: DesktopWindow, among windows: [DesktopWindow]) -> DesktopWindow? {
        windows.first { $0.number == last.number } ?? windows.first { $0.frame == last.frame }
    }

    /// How many widget windows the app keeps in mind. The widget gets a different window for
    /// each display arrangement, so plugging in a monitor shouldn't make the app forget it.
    public static let rememberedLimit = 6

    /// `list` with `window` first (replacing an older entry for the same window), capped.
    public static func remembering(_ window: DesktopWindow, in list: [DesktopWindow]) -> [DesktopWindow] {
        Array(([window] + list.filter { $0.number != window.number }).prefix(rememberedLimit))
    }
}
