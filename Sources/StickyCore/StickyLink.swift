import Foundation

/// `stickynotes://` links the widget opens in the app.
public enum StickyLink: String, CaseIterable, Sendable {
    /// Show the add-a-note box.
    case add

    public static let scheme = "stickynotes"

    public var url: URL {
        var parts = URLComponents()
        parts.scheme = Self.scheme
        parts.host = rawValue
        guard let url = parts.url else { preconditionFailure("StickyLink \(rawValue) is not a valid URL") }
        return url
    }

    /// Accepts `stickynotes://add` in any case, with or without a trailing slash.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let host = url.host?.lowercased(),
              let link = StickyLink(rawValue: host) else { return nil }
        self = link
    }
}
