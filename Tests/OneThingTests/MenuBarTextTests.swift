import AppKit
import XCTest
@testable import OneThing
@testable import OneThingCore

/// The phrase as the menu bar item draws it: cut to fit in a real font, and on the baseline of the system's menu bar
/// text whatever the font. The pictures are drawn into bitmaps; nothing is shown on screen.
@MainActor
final class MenuBarTextTests: XCTestCase {
    private let scale: CGFloat = 2
    private var system: NSFont { PhraseFont.font(for: .system, size: PhraseFont.size) }

    func testTheCutPhraseFitsEveryWidthInARealFont() {
        let long = "Подготовить презентацию для встречи с инвесторами и отправить её до обеда"
        for font in [system, PhraseFont.font(for: FontChoice(family: "Georgia", style: .italic), size: PhraseFont.size)] {
            for width in Phrase.widthChoices {
                let cut = Phrase.fit(long, toWidth: width) { Double(MenuBarText.width(of: $0, font: font)) }
                XCTAssertTrue(cut.hasSuffix(Phrase.ellipsis), "\(width)")
                XCTAssertLessThanOrEqual(Double(MenuBarText.width(of: cut, font: font)), width, "\(width)")
                // One more character would not have fitted.
                let kept = cut.dropLast().count
                let more = String(long.prefix(kept + 1)) + Phrase.ellipsis
                XCTAssertGreaterThan(Double(MenuBarText.width(of: more, font: font)), width, "\(width)")
            }
        }
    }

    func testTheImageIsATemplateAsHighAsTheMarksCanvas() {
        let plain = MenuBarText.image("Дописать главу", font: system)
        XCTAssertTrue(plain.isTemplate)
        XCTAssertEqual(plain.size.height, 22, "the canvas of the mark, centred in the menu bar like it")
        XCTAssertEqual(plain.size.height, MenuBarIcon.canvas.height)
        XCTAssertEqual(plain.size.width, ceil(MenuBarText.width(of: "Дописать главу", font: system)) + 2)
        // The dot of an update comes to the right of the text.
        let dotted = MenuBarText.image("Дописать главу", font: system, badge: true)
        XCTAssertEqual(dotted.size.width, plain.size.width + 2 + MenuBarIcon.badge.width)
    }

    func testTheMarkIsDrawnInTheMiddleOfItsCanvas() throws {
        let rep = bitmap(MenuBarIcon.image(), size: MenuBarIcon.canvas)
        let ink = try XCTUnwrap(inkRows(rep), "the mark has no ink")
        let middle = CGFloat(ink.top + ink.bottom + 1) / 2 / scale
        XCTAssertEqual(middle, MenuBarIcon.canvas.height / 2, accuracy: 1)
    }

    func testEveryFontStandsOnTheBaselineOfTheSystemText() throws {
        let height = MenuBarText.height
        let baseline = MenuBarText.baseline(height: height)
        for choice in [FontChoice.system, FontChoice(family: "Georgia", style: .regular),
                       FontChoice(family: "Menlo", style: .bold), FontChoice(family: "Helvetica", style: .italic)] {
            let font = PhraseFont.font(for: choice, size: PhraseFont.size)
            // The bottom of the stems of an «H» is the baseline.
            let rep = bitmap(MenuBarText.image("H", font: font), size: NSSize(width: 20, height: height))
            let ink = try XCTUnwrap(inkRows(rep), "\(choice)")
            let bottom = (CGFloat(rep.pixelsHigh) - CGFloat(ink.bottom + 1)) / scale
            XCTAssertEqual(bottom, baseline, accuracy: 0.5, "\(choice.family.isEmpty ? "system" : choice.family)")
        }
    }

    /// The baseline of the menu bar font is the one AppKit gives a native title: a plain button, as the status item's
    /// button is, with the title set in the menu bar font.
    func testTheBaselineIsTheOneOfANativeTitle() throws {
        let height = MenuBarText.height
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 60, height: height))
        button.title = "H"
        button.isBordered = false
        button.font = NSFont.menuBarFont(ofSize: 0)
        button.alignment = .center
        button.appearance = NSAppearance(named: .darkAqua)
        let window = NSWindow(contentRect: button.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = button
        button.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(button.bitmapImageRepForCachingDisplay(in: button.bounds))
        button.cacheDisplay(in: button.bounds, to: rep)
        let ink = try XCTUnwrap(inkRows(rep))
        let native = (CGFloat(rep.pixelsHigh) - CGFloat(ink.bottom + 1)) / (CGFloat(rep.pixelsHigh) / height)
        XCTAssertEqual(native, MenuBarText.baseline(height: height), accuracy: 0.5)
    }

    // MARK: Drawing

    /// `image` drawn into a bitmap of `size` points at 2x.
    private func bitmap(_ image: NSImage, size: NSSize) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// The first and the last pixel row, counted from the top, that hold ink; nil when there is none.
    private func inkRows(_ rep: NSBitmapImageRep) -> (top: Int, bottom: Int)? {
        var top = Int.max, bottom = -1
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide where (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.5 {
                top = min(top, y)
                bottom = max(bottom, y)
            }
        }
        return bottom < 0 ? nil : (top, bottom)
    }
}
