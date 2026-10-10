import XCTest
@testable import OneThingCore

/// The phrase: cleaned when saved, cut to the width of the menu bar item, and the settings around it. Every test has
/// settings of its own, kept in memory, so nothing here touches the app's real settings or leaves a file.
final class PhraseTests: XCTestCase {
    private var defaults = MemoryStore()

    override func setUp() {
        defaults = MemoryStore()
    }

    /// Ten points to a character, so the width is the length.
    private let tenPoints: (String) -> Double = { Double($0.count) * 10 }

    // MARK: Cleaning

    func testCleanedMakesOneLine() {
        XCTAssertEqual(Phrase.cleaned("  Дописать\n\tглаву   сегодня \n"), "Дописать главу сегодня")
        XCTAssertEqual(Phrase.cleaned(" \n\t "), "")
    }

    func testCleanedKeepsNoMoreThanTheLimit() {
        XCTAssertEqual(Phrase.cleaned(String(repeating: "я", count: 500)).count, Phrase.maxLength)
        // The cut does not leave a space at the end.
        XCTAssertFalse(Phrase.cleaned(String(repeating: "слово ", count: 100)).hasSuffix(" "))
    }

    func testLimitedOnlyCuts() {
        XCTAssertEqual(Phrase.limited("  a  "), "  a  ")
        XCTAssertEqual(Phrase.limited(String(repeating: "x", count: 200)).count, Phrase.maxLength)
    }

    // MARK: Saving

    func testSaveKeepsTheCleanedPhrase() {
        XCTAssertEqual(Phrase.save("  Позвонить\nбабушке ", in: defaults), "Позвонить бабушке")
        XCTAssertEqual(Phrase.saved(in: defaults), "Позвонить бабушке")
        XCTAssertEqual(defaults.string(forKey: Phrase.key), "Позвонить бабушке")
    }

    func testANewPhraseReplacesTheOldOne() {
        Phrase.save("Первая", in: defaults)
        Phrase.save("Вторая", in: defaults)
        XCTAssertEqual(Phrase.saved(in: defaults), "Вторая")
    }

    func testAnEmptyPhraseIsRemoved() {
        Phrase.save("Что-то", in: defaults)
        XCTAssertEqual(Phrase.save("  \n ", in: defaults), "")
        XCTAssertNil(defaults.object(forKey: Phrase.key))
        XCTAssertEqual(Phrase.saved(in: defaults), "")
    }

    func testNothingSavedIsAnEmptyPhrase() {
        XCTAssertEqual(Phrase.saved(in: defaults), "")
    }

    // MARK: Cutting to the width

    func testAShortPhraseIsLeftAlone() {
        XCTAssertEqual(Phrase.fit("abc", toWidth: 100, measure: tenPoints), "abc")
        // As wide as the limit is still not cut.
        XCTAssertEqual(Phrase.fit("abcdefghij", toWidth: 100, measure: tenPoints), "abcdefghij")
    }

    func testALongPhraseIsCutToTheWidthWithAnEllipsis() {
        // Nine characters and the ellipsis make 100 points.
        XCTAssertEqual(Phrase.fit("abcdefghijklmnop", toWidth: 100, measure: tenPoints), "abcdefghi…")
    }

    func testTheSpaceBeforeTheEllipsisGoes() {
        XCTAssertEqual(Phrase.fit("hello world and more", toWidth: 70, measure: tenPoints), "hello…")
    }

    func testACharacterIsNeverSplit() {
        let family = "👨‍👩‍👧‍👦"
        XCTAssertEqual(Phrase.fit("ab" + family + "cd" + family, toWidth: 50, measure: tenPoints), "ab" + family + "c…")
    }

    func testWhenNothingFitsTheEllipsisStays() {
        XCTAssertEqual(Phrase.fit("abcdef", toWidth: 5, measure: tenPoints), "…")
    }

    func testTheCutIsTheLongestThatFits() {
        // Letters of different widths: the cut is still the longest start that fits with the ellipsis.
        let widths: [Character: Double] = ["i": 4, "m": 16]
        let measure: (String) -> Double = { $0.reduce(0) { $0 + (widths[$1] ?? 10) } }
        let text = "iiimmmiiimmmiiimmm"
        let cut = Phrase.fit(text, toWidth: 90, measure: measure)
        XCTAssertLessThanOrEqual(measure(cut), 90)
        let kept = cut.dropLast().count
        let next = String(text.prefix(kept + 1)) + Phrase.ellipsis
        XCTAssertGreaterThan(measure(next), 90)
    }

    // MARK: Settings

    func testTheWidthDefaultsAndStaysInRange() {
        XCTAssertEqual(Phrase.maxWidth(in: defaults), Phrase.defaultWidth)
        XCTAssertTrue(Phrase.widthChoices.contains(Phrase.defaultWidth))
        defaults.set(120.0, forKey: Phrase.maxWidthKey)
        XCTAssertEqual(Phrase.maxWidth(in: defaults), 120)
        defaults.set(150, forKey: Phrase.maxWidthKey)
        XCTAssertEqual(Phrase.maxWidth(in: defaults), 150)
        defaults.set(5.0, forKey: Phrase.maxWidthKey)
        XCTAssertEqual(Phrase.maxWidth(in: defaults), Phrase.widthRange.lowerBound)
        defaults.set(5000.0, forKey: Phrase.maxWidthKey)
        XCTAssertEqual(Phrase.maxWidth(in: defaults), Phrase.widthRange.upperBound)
        defaults.set("wide", forKey: Phrase.maxWidthKey)
        XCTAssertEqual(Phrase.maxWidth(in: defaults), Phrase.defaultWidth)
    }

    func testTheMenuBarShowsTheCutPhraseOrTheMark() {
        // No phrase: the mark.
        XCTAssertNil(Phrase.menuBarText(in: defaults, measure: tenPoints))
        Phrase.save("abcdefghijklmnopqrstuvwxyz", in: defaults)
        // The width of 200 points: 19 characters and the ellipsis.
        XCTAssertEqual(Phrase.menuBarText(in: defaults, measure: tenPoints), "abcdefghijklmnopqrs…")
        defaults.set(100.0, forKey: Phrase.maxWidthKey)
        XCTAssertEqual(Phrase.menuBarText(in: defaults, measure: tenPoints), "abcdefghi…")
        // «Скрыть текст»: the mark again, the phrase stays.
        defaults.set(true, forKey: Phrase.hideTextKey)
        XCTAssertNil(Phrase.menuBarText(in: defaults, measure: tenPoints))
        XCTAssertEqual(Phrase.saved(in: defaults), "abcdefghijklmnopqrstuvwxyz")
    }
}
