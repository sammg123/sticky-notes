import CoreGraphics
import Foundation

/// A press on a note's line on the widget. It stays a click (which edits the note) until it is
/// held for `holdDelay` or moves more than `dragSlop`; from then on it is a drag that reorders.
public struct WidgetPress: Equatable, Sendable {
    public static let holdDelay: TimeInterval = 0.25
    public static let dragSlop: Double = 4

    public let start: CGPoint
    /// Seconds since boot, as `NSEvent.timestamp` counts them.
    public let startTime: TimeInterval

    public init(start: CGPoint, startTime: TimeInterval) {
        self.start = start
        self.startTime = startTime
    }

    /// True once the press has become a drag.
    public func isDrag(at point: CGPoint, time: TimeInterval) -> Bool {
        time - startTime >= Self.holdDelay || hypot(point.x - start.x, point.y - start.y) > Self.dragSlop
    }
}
