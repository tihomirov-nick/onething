// One Thing (one phrase in the menu bar): an opening double quotation mark, two solid "6" shapes. The menu bar shows
// the phrase itself; the mark stands in when the phrase is empty. Solid at every size, so it takes no line width.
// Box conventions: Glyph.swift.
import CoreGraphics

enum OneThing {
    /// The ink of the mark in the box: the menu bar and the app icon fit it to their room (Glyph.swift).
    static let bounds = CGRect(x: 9.2, y: 20.7, width: 81.6, height: 61.4)

    static func draw(_ ctx: CGContext) {
        let p = Glyph.p
        ctx.saveGState()
        ctx.translateBy(x: 50, y: 51.5)
        ctx.scaleBy(x: 1.2, y: 1.2)
        ctx.translateBy(x: -50, y: -51.5)
        for cx: CGFloat in [31, 69] {
            let y: CGFloat = 62, r: CGFloat = 15
            let tail = CGMutablePath()
            tail.move(to: p(cx - r, y))
            tail.addCurve(to: p(cx + 6, y - 36), control1: p(cx - r, y - 18), control2: p(cx - 8, y - 30))
            tail.addCurve(to: p(cx + 8, y - 31), control1: p(cx + 9, y - 37), control2: p(cx + 10.5, y - 33))
            tail.addCurve(to: p(cx - 3, y - 10), control1: p(cx - 1, y - 26), control2: p(cx - 5, y - 18))
            tail.closeSubpath()
            Glyph.fill(ctx, tail.union(Glyph.disc(p(cx, y), r)))
        }
        ctx.restoreGState()
    }
}
