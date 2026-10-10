import AppKit
import SwiftUI
import OneThingCore

/// `--render-previews <folder>`: the menu bar item (with a phrase in three fonts, a long phrase cut to the width, the
/// mark), the panel with the field, Settings and the list of fonts drawn into one picture, <folder>/preview.png,
/// through hosting views in windows that are never shown. Nothing starts: no status item, no updater, no login item,
/// no shortcut, and nothing is written to UserDefaults.
@MainActor
enum PreviewRenderer {
    /// What a strip of menu bar shows in its middle.
    private enum Item {
        case text(String, NSFont, badge: Bool)
        case mark(badge: Bool)
    }

    /// A part of the left column: its height and how it draws itself into the rectangle it is given.
    private struct Block {
        let height: CGFloat
        let draw: (NSRect) -> Void
    }

    static func run(into folder: URL) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let sample = "Дописать главу"
        let long = "Подготовить презентацию для встречи с инвесторами и отправить её до обеда"
        let size = PhraseFont.size
        let system = PhraseFont.font(for: .system, size: size)
        let cut = Phrase.fit(long, toWidth: Phrase.defaultWidth) { Double(MenuBarText.width(of: $0, font: system)) }
        // Two installed families with the letters of the sample, set in two different faces.
        let serif = example(["Georgia", "Palatino", "Times New Roman"], .italic, sample, size)
        let mono = example(["Menlo", "Courier New", "Monaco"], .bold, sample, size)

        // The draft stands in for the saved phrase, so the user's defaults stay untouched.
        PhraseDraft.shared.text = sample
        PhraseDraft.shared.font = system
        let panelSystem = snapshot(PanelView())
        PhraseDraft.shared.font = serif.font
        let panelSerif = snapshot(PanelView())
        let list = snapshot(FontList(selected: serif.family, pick: { _ in }))
        guard let panelSystem, let panelSerif, let list, let settings = snapshot(SettingsWindow.makeWindow()) else {
            print("failed to draw the views")
            return
        }

        let margin: CGFloat = 24, bar: CGFloat = 24, zoom: CGFloat = 4
        let left: CGFloat = 300
        let secondary = NSColor(white: 1, alpha: 0.55)

        func caption(_ text: String) -> Block {
            Block(height: 20) { rect in label(text, at: NSPoint(x: rect.minX + 2, y: rect.minY + 4), color: secondary) }
        }
        func gap(_ height: CGFloat) -> Block { Block(height: height) { _ in } }
        func strip(_ item: Item) -> Block {
            Block(height: bar) { rect in drawStrip(rect, item) }
        }
        /// The panel hangs under the item at the middle of the strip above it.
        func panel(_ shot: (image: CGImage, size: NSSize)) -> Block {
            Block(height: 6 + shot.size.height) { rect in
                NSGraphicsContext.current?.cgContext.draw(shot.image, in: NSRect(x: rect.midX - shot.size.width / 2, y: rect.minY,
                                                                                 width: shot.size.width, height: shot.size.height))
            }
        }
        let zoomed = NSSize(width: MenuBarIcon.canvas.width * zoom, height: MenuBarIcon.canvas.height * zoom)
        let blocks: [Block] = [
            caption("Системный шрифт: строка меню и поле в окошке"),
            strip(.text(sample, system, badge: false)), panel(panelSystem), gap(10),
            caption(serif.label),
            strip(.text(sample, serif.font, badge: false)), panel(panelSerif), gap(10),
            caption(mono.label),
            strip(.text(sample, mono.font, badge: false)), gap(14),
            caption("Длинная фраза, ширина 200 pt"),
            strip(.text(cut, system, badge: false)), gap(10),
            caption("Фразы нет: знак"),
            strip(.mark(badge: false)), gap(10),
            caption("Новая версия: точка у фразы и у знака, знак ×4"),
            strip(.text(sample, system, badge: true)), gap(8),
            Block(height: zoomed.height) { rect in
                white(MenuBarIcon.image(badge: true)).draw(in: NSRect(x: rect.midX - zoomed.width / 2, y: rect.minY,
                                                                       width: zoomed.width, height: zoomed.height))
            },
        ]
        let leftHeight = blocks.reduce(0) { $0 + $1.height }
        let width = margin + left + margin + settings.size.width + margin + list.size.width + margin
        let height = margin + max(leftHeight, settings.size.height, list.size.height) + margin

        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = NSSize(width: width, height: height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(white: 0.17, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        // The left column from the top down.
        var top = height - margin
        for block in blocks {
            block.draw(NSRect(x: margin, y: top - block.height, width: left, height: block.height))
            top -= block.height
        }
        // Settings and the list of fonts on the right.
        let settingsRect = NSRect(x: margin + left + margin, y: height - margin - settings.size.height,
                                  width: settings.size.width, height: settings.size.height)
        NSGraphicsContext.current?.cgContext.draw(settings.image, in: settingsRect)
        let listRect = NSRect(x: settingsRect.maxX + margin, y: height - margin - list.size.height,
                              width: list.size.width, height: list.size.height)
        NSGraphicsContext.current?.cgContext.draw(list.image, in: listRect)
        label("Список шрифтов (окно по щелчку на «Шрифт»)", at: NSPoint(x: listRect.minX + 2, y: listRect.minY - 16), color: secondary)
        NSGraphicsContext.restoreGraphicsState()

        let url = folder.appendingPathComponent("preview.png")
        if let data = rep.representation(using: .png, properties: [:]), (try? data.write(to: url)) != nil {
            print("wrote \(url.path)")
        } else {
            print("failed to write \(url.path)")
        }
    }

    /// The first of `families` that is installed and has the letters of `sample`, in the face `style`.
    private static func example(_ families: [String], _ style: FontStyle, _ sample: String, _ size: CGFloat)
        -> (family: String, label: String, font: NSFont) {
        for family in families where PhraseFont.isInstalled(family) {
            let font = PhraseFont.font(for: FontChoice(family: family, style: style), size: size)
            if font.coveredCharacterSet.isSuperset(of: CharacterSet(charactersIn: sample)) {
                return (family, "\(family), \(style.title.lowercased())", font)
            }
        }
        return ("", "Системный (нет подходящего шрифта)", PhraseFont.font(for: .system, size: size))
    }

    /// A strip of menu bar with the item at its middle, as the item is drawn in the real menu bar.
    private static func drawStrip(_ rect: NSRect, _ item: Item) {
        NSColor(white: 0.08, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
        let image: NSImage
        switch item {
        case .text(let text, let font, let badge): image = white(MenuBarText.image(text, font: font, badge: badge))
        case .mark(let badge): image = white(MenuBarIcon.image(badge: badge))
        }
        image.draw(in: NSRect(x: rect.midX - image.size.width / 2, y: rect.midY - image.size.height / 2,
                              width: image.size.width, height: image.size.height))
    }

    private static func label(_ text: String, at point: NSPoint, color: NSColor) {
        text.draw(at: point, withAttributes: [.font: NSFont.systemFont(ofSize: 10.5), .foregroundColor: color])
    }

    /// The view as drawn by a real hosting view, at its own size.
    private static func snapshot<V: View>(_ view: V) -> (image: CGImage, size: NSSize)? {
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return rep.cgImage.map { ($0, size) }
    }

    /// A window with its title bar, never ordered on screen.
    private static func snapshot(_ window: NSWindow) -> (image: CGImage, size: NSSize)? {
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        guard let frame = window.contentView?.superview else { return nil }
        frame.layoutSubtreeIfNeeded()
        guard let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { return nil }
        frame.cacheDisplay(in: frame.bounds, to: rep)
        return rep.cgImage.map { ($0, frame.bounds.size) }
    }

    /// A template image in white, as the dark menu bar shows it.
    private static func white(_ image: NSImage) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            NSColor.white.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
