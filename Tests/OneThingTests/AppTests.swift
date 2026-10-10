import AppKit
import Carbon.HIToolbox
import XCTest
@testable import OneThing

/// The family's menu bar standard. Nothing here touches the menu bar: the menu is built, never shown.
@MainActor
final class AppTests: XCTestCase {
    func testTheIconIsATemplateImage22PointsHigh() {
        for badge in [false, true] {
            let image = MenuBarIcon.image(badge: badge)
            XCTAssertEqual(image.size.height, 22)
            XCTAssertEqual(image.size, MenuBarIcon.canvas)
            XCTAssertTrue(image.isTemplate)
        }
    }

    func testTheMenuEndsWithTheFamilyItems() {
        let items = StatusItem.menu().items
        let tail = Array(items.suffix(5))
        XCTAssertEqual(tail.map(\.isSeparatorItem), [false, false, false, true, false])
        XCTAssertEqual(tail[0].action, #selector(AppDelegate.showSettings(_:)))
        XCTAssertEqual(tail[0].keyEquivalent, ",")
        XCTAssertEqual(tail[1].action, #selector(AppDelegate.checkForUpdates(_:)))
        XCTAssertEqual(tail[2].action, #selector(AppDelegate.showAbout(_:)))
        XCTAssertEqual(tail[4].action, #selector(NSApplication.terminate(_:)))
        XCTAssertEqual(tail[4].keyEquivalent, "q")
        // The app's own actions come first, a separator after them.
        let actions = AppActions.menuItems().count
        XCTAssertEqual(items.count, actions + (actions > 0 ? 1 : 0) + 5)
    }

    func testNoShortcutIsSetUntilTheUserRecordsOne() {
        let defaults = MemoryStore()
        XCTAssertNil(Shortcut.saved(in: defaults))
        let shortcut = Shortcut(keyCode: UInt32(kVK_ANSI_O), modifiers: UInt32(controlKey | optionKey | cmdKey))
        Shortcut.save(shortcut, in: defaults)
        XCTAssertEqual(Shortcut.saved(in: defaults), shortcut)
        XCTAssertTrue(shortcut.display.hasPrefix("⌃⌥⌘"))
        Shortcut.save(nil, in: defaults)
        XCTAssertNil(Shortcut.saved(in: defaults))
    }

    func testTheAppIsBusyOnlyWhileTheFieldIsOpen() {
        // The panel has never been shown here, so it is not open.
        XCTAssertFalse(AppActions.isBusy)
    }

    /// `swift scripts/make_icon.swift` runs a single file, so the script carries copies of the two files that draw the
    /// mark. They must stay the files' words.
    func testTheIconScriptDrawsTheSameMarkAsTheApp() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let script = try String(contentsOf: root.appendingPathComponent("scripts/make_icon.swift"), encoding: .utf8)
        for name in ["Glyph", "OneThing"] {
            let source = try String(contentsOf: root.appendingPathComponent("Sources/OneThing/\(name).swift"), encoding: .utf8)
                .replacingOccurrences(of: "import CoreGraphics\n", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertTrue(script.contains(source), "scripts/make_icon.swift differs from Sources/OneThing/\(name).swift")
        }
    }
}
