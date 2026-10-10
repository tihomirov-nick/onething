import AppKit
import XCTest
@testable import OneThing
@testable import OneThingCore

/// The font of the phrase: the choice is saved, an installed family is used, and what has gone from the Mac falls back
/// quietly. Every test has settings of its own, in memory, so nothing here touches the app's real settings.
@MainActor
final class FontTests: XCTestCase {
    private var defaults = MemoryStore()
    private let gone = FontChoice(family: "Gone Family 7F3A", style: .boldItalic)

    override func setUp() {
        defaults = MemoryStore()
    }

    // MARK: Saving the choice

    func testNothingSavedIsTheSystemFont() {
        XCTAssertEqual(FontChoice.saved(in: defaults), .system)
        XCTAssertTrue(FontChoice.saved(in: defaults).isSystem)
    }

    func testTheChoiceIsSavedAndRead() {
        FontChoice(family: "Menlo", style: .boldItalic).save(in: defaults)
        XCTAssertEqual(FontChoice.saved(in: defaults), FontChoice(family: "Menlo", style: .boldItalic))
        FontChoice(family: "Georgia", style: .regular).save(in: defaults)
        XCTAssertEqual(FontChoice.saved(in: defaults), FontChoice(family: "Georgia", style: .regular))
    }

    func testTheSystemFontAndTheRegularFaceAreStoredAsNothing() {
        FontChoice(family: "Menlo", style: .bold).save(in: defaults)
        FontChoice.system.save(in: defaults)
        XCTAssertNil(defaults.object(forKey: FontChoice.familyKey))
        XCTAssertNil(defaults.object(forKey: FontChoice.styleKey))
    }

    func testAnUnknownStyleReadsAsRegular() {
        defaults.set("Menlo", forKey: FontChoice.familyKey)
        defaults.set("heavy", forKey: FontChoice.styleKey)
        XCTAssertEqual(FontChoice.saved(in: defaults), FontChoice(family: "Menlo", style: .regular))
    }

    // MARK: Installed fonts

    func testAnInstalledFamilyIsUsedInTheChosenFace() {
        let manager = NSFontManager.shared
        let bold = PhraseFont.font(for: FontChoice(family: "Menlo", style: .bold), size: 13)
        XCTAssertEqual(bold.familyName, "Menlo")
        XCTAssertEqual(bold.pointSize, 13)
        XCTAssertTrue(manager.traits(of: bold).contains(.boldFontMask))
        let italic = PhraseFont.font(for: FontChoice(family: "Menlo", style: .italic), size: 13)
        XCTAssertTrue(manager.traits(of: italic).contains(.italicFontMask))
        XCTAssertFalse(manager.traits(of: italic).contains(.boldFontMask))
        let regular = PhraseFont.font(for: FontChoice(family: "Menlo", style: .regular), size: 13)
        XCTAssertTrue(manager.traits(of: regular).isDisjoint(with: [.boldFontMask, .italicFontMask]))
    }

    func testTheStylesAFamilyHas() {
        XCTAssertEqual(PhraseFont.styles(of: "Menlo"), FontStyle.allCases)
        XCTAssertEqual(PhraseFont.styles(of: ""), FontStyle.allCases)
        XCTAssertEqual(PhraseFont.styles(of: gone.family), [])
    }

    func testTheSystemFontComesInEveryFace() {
        let manager = NSFontManager.shared
        let bold = PhraseFont.font(for: FontChoice(family: "", style: .bold), size: 13)
        XCTAssertTrue(manager.traits(of: bold).contains(.boldFontMask))
        let italic = PhraseFont.font(for: FontChoice(family: "", style: .italic), size: 13)
        XCTAssertTrue(manager.traits(of: italic).contains(.italicFontMask))
    }

    func testTheFamilyListHasTheInstalledFamilies() {
        XCTAssertTrue(PhraseFont.families.contains("Menlo"))
        XCTAssertGreaterThan(PhraseFont.families.count, 12, "the list is long enough to need a search field")
    }

    // MARK: What is gone

    func testAFontThatIsGoneFallsBackToTheSystemFont() {
        XCTAssertFalse(PhraseFont.isInstalled(gone.family))
        XCTAssertEqual(PhraseFont.effective(gone), .system)
        let font = PhraseFont.font(for: gone, size: 13)
        XCTAssertEqual(font, PhraseFont.font(for: .system, size: 13))
        XCTAssertEqual(font.fontName, NSFont.menuBarFont(ofSize: 13).fontName)
    }

    func testTheSavedChoiceStaysWhileTheFontIsAway() {
        // The fall back is only how the choice is shown: a font that comes back is used again.
        gone.save(in: defaults)
        _ = PhraseFont.font(for: FontChoice.saved(in: defaults), size: 13)
        XCTAssertEqual(FontChoice.saved(in: defaults), gone)
    }

    func testAFaceTheFamilyLacksFallsBackToItsRegularFace() throws {
        let single = PhraseFont.families.first { PhraseFont.styles(of: $0) == [.regular] }
        try XCTSkipIf(single == nil, "no installed family with a single face")
        let family = try XCTUnwrap(single)
        let choice = FontChoice(family: family, style: .boldItalic)
        XCTAssertEqual(PhraseFont.effective(choice), FontChoice(family: family, style: .regular))
        XCTAssertEqual(PhraseFont.font(for: choice, size: 13).familyName, family)
    }
}
