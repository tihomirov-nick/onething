import Foundation

/// The phrase of the menu bar item and the settings that shape it. All of it lives in UserDefaults (any `KeyValueStore`
/// will do, so the tests need no file): the phrase is
/// cleaned up when it is saved and cut to the width from Settings when it is shown. Plain logic with no AppKit, so the
/// tests can try it with any defaults: the caller measures the width of a text, in the font the item is drawn in.
public enum Phrase {
    public static let key = "phrase"
    public static let maxWidthKey = "maxWidth"
    public static let hideTextKey = "hideText"

    /// Characters kept; a pasted paragraph is cut here.
    public static let maxLength = 140
    /// The widths Settings offers, in points.
    public static let widthChoices: [Double] = [80, 120, 160, 200, 260, 320, 400]
    public static let defaultWidth: Double = 200
    /// What a stored width is held to, whoever wrote it.
    public static let widthRange: ClosedRange<Double> = 40...800
    public static let ellipsis = "…"

    // MARK: Text

    /// One line: line breaks, tabs and runs of spaces become one space, the ends are trimmed, `maxLength` characters at most.
    public static func cleaned(_ text: String) -> String {
        let oneLine = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return String(oneLine.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
    }

    /// While typing: at most `maxLength` characters, nothing else is touched.
    public static func limited(_ text: String) -> String {
        text.count > maxLength ? String(text.prefix(maxLength)) : text
    }

    /// `text` as one line that fits `width`: cut with an ellipsis where it would run out, never in the middle of a
    /// character. `measure` gives the width of a text in the font it is drawn in.
    public static func fit(_ text: String, toWidth width: Double, measure: (String) -> Double) -> String {
        let line = cleaned(text)
        guard measure(line) > width else { return line }
        let characters = Array(line)
        func candidate(_ count: Int) -> String {
            String(characters.prefix(count)).trimmingCharacters(in: .whitespaces) + ellipsis
        }
        // The most characters that still fit with the ellipsis. The whole line does not fit, so it is at most one less.
        var low = 0, high = characters.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if measure(candidate(middle)) <= width { low = middle } else { high = middle - 1 }
        }
        // Kerning can make a longer start narrower; the answer must fit anyway.
        while low > 0, measure(candidate(low)) > width { low -= 1 }
        return candidate(low)
    }

    // MARK: Storage

    /// The saved phrase; empty when there is none.
    public static func saved(in defaults: KeyValueStore = UserDefaults.standard) -> String {
        cleaned(defaults.string(forKey: key) ?? "")
    }

    /// Cleans `text` up and keeps it; an empty phrase is removed. Returns what was kept.
    @discardableResult
    public static func save(_ text: String, in defaults: KeyValueStore = UserDefaults.standard) -> String {
        let phrase = cleaned(text)
        if phrase.isEmpty {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(phrase, forKey: key)
        }
        return phrase
    }

    /// The widest the text in the menu bar may be, in points.
    public static func maxWidth(in defaults: KeyValueStore = UserDefaults.standard) -> Double {
        guard let stored = (defaults.object(forKey: maxWidthKey) as? NSNumber)?.doubleValue else { return defaultWidth }
        return min(max(stored, widthRange.lowerBound), widthRange.upperBound)
    }

    /// «Скрыть текст»: the menu bar keeps only the mark.
    public static func hidesText(in defaults: KeyValueStore = UserDefaults.standard) -> Bool {
        defaults.bool(forKey: hideTextKey)
    }

    /// The text of the menu bar item, cut to the width from Settings; nil when the item shows the mark instead: there
    /// is no phrase, or the text is hidden.
    public static func menuBarText(in defaults: KeyValueStore = UserDefaults.standard, measure: (String) -> Double) -> String? {
        guard !hidesText(in: defaults) else { return nil }
        let phrase = saved(in: defaults)
        guard !phrase.isEmpty else { return nil }
        return fit(phrase, toWidth: maxWidth(in: defaults), measure: measure)
    }
}
