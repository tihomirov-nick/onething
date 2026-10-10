import AppKit
import CoreText
import OneThingCore

/// The phrase as the menu bar item shows it. The app draws the text itself, into a template image as high as the mark's
/// canvas (22 pt, centred in the menu bar like the mark), so every font stands on the baseline of the system's menu bar
/// text. A native title would centre the line box of each font, and the baseline would move with the font's metrics.
enum MenuBarText {
    /// The height of the item's image: the canvas of the mark. The button centres it in the menu bar, and the baseline
    /// below counts from the middle of the height, so the text stands where the system's own menu bar text stands.
    static var height: CGFloat { MenuBarIcon.canvas.height }

    static func line(_ text: String, font: NSFont) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
    }

    static func width(of text: String, font: NSFont) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line(text, font: font), nil, nil, nil))
    }

    /// How high above the bottom of an item `height` tall the system's menu bar text has its baseline: the line of the
    /// menu bar font (ascent and descent, each rounded up as AppKit lays text out) centred in the item.
    static func baseline(height: CGFloat) -> CGFloat {
        let system = NSFont.menuBarFont(ofSize: 0)
        let descent = ceil(-system.descender)
        return (height - (ceil(system.ascender) + descent)) / 2 + descent
    }

    /// What the item shows now: the saved phrase cut to the width from Settings and the font it is set in; nil when
    /// the item shows the mark (no phrase, or «Скрыть текст»).
    static func current() -> (text: String, font: NSFont)? {
        let font = PhraseFont.current(size: PhraseFont.size)
        return Phrase.menuBarText { Double(width(of: $0, font: font)) }.map { ($0, font) }
    }

    /// The text as a template image the width of the text, which macOS tints for the menu bar. `badge` adds the dot of
    /// an update the user has not answered yet, to the right of the text and as high as on the mark.
    static func image(_ text: String, font: NSFont, badge: Bool = false) -> NSImage {
        let line = line(text, font: font)
        let inset: CGFloat = 1
        let textWidth = ceil(CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
        let dot = MenuBarIcon.badge.size
        let size = NSSize(width: inset + textWidth + inset + (badge ? 2 + dot.width : 0), height: height)
        let baseline = baseline(height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.textMatrix = .identity
            ctx.textPosition = CGPoint(x: inset, y: baseline)
            CTLineDraw(line, ctx)
            if badge {
                let top = (size.height - MenuBarIcon.canvas.height) / 2 + MenuBarIcon.badge.minY
                ctx.fillEllipse(in: CGRect(x: size.width - dot.width, y: size.height - top - dot.height,
                                           width: dot.width, height: dot.height))
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = text
        return image
    }
}
