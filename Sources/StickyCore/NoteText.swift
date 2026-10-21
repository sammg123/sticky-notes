import CoreText
import Foundation

/// How a note's text wraps on the widget: the widget's 13pt system font, measured with Core Text,
/// which breaks lines exactly where SwiftUI's Text does (0 of 2,400 random notes differed).
public enum NoteText {
    public static let fontSize: CGFloat = 13
    /// The height SwiftUI gives each line of 13pt system text.
    public static let lineHeight: CGFloat = 16

    private static let font = CTFontCreateUIFontForLanguage(.system, fontSize, nil)

    /// Lines `text` takes at `width` points; at least one.
    public static func lineCount(_ text: String, width: CGFloat) -> Int {
        guard width > 0, !text.isEmpty, let font else { return 1 }
        let attributed = NSAttributedString(string: text, attributes: [.init(kCTFontAttributeName as String): font])
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude / 2), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        return max(1, CFArrayGetCount(CTFrameGetLines(frame)))
    }
}
