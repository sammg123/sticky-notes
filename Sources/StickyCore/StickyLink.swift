import Foundation

/// `stickynotes://` links the widget opens in the app.
public enum StickyLink: Equatable, Sendable {
    /// Show the box (add field and the full list).
    case add
    /// Edit this note's text in place, over its line on the widget. `row` is the line the widget
    /// drew it on, which can differ from the note's place in the file if the widget hasn't
    /// redrawn yet; the edit field goes where the user clicked.
    case edit(UUID, row: Int?)

    public static let scheme = "stickynotes"

    public var url: URL {
        var parts = URLComponents()
        parts.scheme = Self.scheme
        switch self {
        case .add:
            parts.host = "add"
        case .edit(let id, let row):
            parts.host = "edit"
            parts.path = "/" + id.uuidString
            parts.queryItems = row.map { [URLQueryItem(name: "row", value: String($0))] }
        }
        guard let url = parts.url else { preconditionFailure("StickyLink \(self) is not a valid URL") }
        return url
    }

    /// Accepts `stickynotes://add` and `stickynotes://edit/<uuid>[?row=<n>]`, in any case, with
    /// or without a trailing slash. A nonsense row is dropped rather than failing the link.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme, let host = url.host?.lowercased() else { return nil }
        let rest = url.path.split(separator: "/").map(String.init)
        switch (host, rest.count) {
        case ("add", 0):
            self = .add
        case ("edit", 1):
            guard let id = UUID(uuidString: rest[0]) else { return nil }
            let row = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "row" }?.value.flatMap(Int.init)
            self = .edit(id, row: row.flatMap { $0 >= 0 ? $0 : nil })
        default:
            return nil
        }
    }
}
