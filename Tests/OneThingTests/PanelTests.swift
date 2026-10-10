import AppKit
import XCTest
@testable import OneThing
@testable import OneThingCore

/// The field of the panel: Return keeps the phrase, anything abandoned is gone at the next opening. The draft works on
/// settings in memory and nothing is shown.
@MainActor
final class PanelTests: XCTestCase {
    private var store = MemoryStore()
    private var draft: PhraseDraft!
    private var commits = 0

    override func setUp() {
        store = MemoryStore()
        commits = 0
        draft = PhraseDraft(store: store)
        draft.didCommit = { [unowned self] in commits += 1 }
    }

    func testTheFieldStartsWithTheSavedPhrase() {
        Phrase.save("Дописать главу", in: store)
        XCTAssertEqual(PhraseDraft(store: store).text, "Дописать главу")
        XCTAssertEqual(PhraseDraft(store: MemoryStore()).text, "")
    }

    func testReturnKeepsTheCleanedPhraseAndSaysSo() {
        draft.text = "  Дописать\nглаву "
        draft.commit()
        XCTAssertEqual(Phrase.saved(in: store), "Дописать главу")
        XCTAssertEqual(draft.text, "Дописать главу")
        XCTAssertEqual(commits, 1)
    }

    func testAnEmptyFieldRemovesThePhrase() {
        Phrase.save("Что-то", in: store)
        draft.reload()
        draft.text = "   "
        draft.commit()
        XCTAssertEqual(Phrase.saved(in: store), "")
        XCTAssertNil(store.object(forKey: Phrase.key))
        XCTAssertEqual(commits, 1)
    }

    func testWhatWasTypedAndAbandonedIsGoneAtTheNextOpening() {
        Phrase.save("Сохранённая", in: store)
        draft.reload()
        draft.text = "Набрано, но не сохранено"
        // Esc or a click elsewhere closes the panel; the next opening reloads the draft.
        draft.reload()
        XCTAssertEqual(draft.text, "Сохранённая")
        XCTAssertEqual(commits, 0)
        XCTAssertEqual(Phrase.saved(in: store), "Сохранённая")
    }

    func testTheFieldIsSetInTheChosenFont() {
        FontChoice(family: "Menlo", style: .bold).save(in: store)
        draft.reload()
        XCTAssertEqual(draft.font.familyName, "Menlo")
        XCTAssertEqual(draft.font.pointSize, PhraseFont.size)
        // A font that has gone from the Mac: the system font, quietly.
        FontChoice(family: "Gone Family 7F3A", style: .bold).save(in: store)
        draft.reload()
        XCTAssertEqual(draft.font, PhraseFont.font(for: .system, size: PhraseFont.size))
    }

    // MARK: The field itself

    func testReturnInTheFieldKeepsThePhrase() {
        let coordinator = PhraseField.Coordinator(draft)
        let field = NSTextField(string: "Позвонить бабушке")
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        let handled = coordinator.control(field, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertNewline(_:)))
        XCTAssertTrue(handled)
        XCTAssertEqual(Phrase.saved(in: store), "Позвонить бабушке")
        XCTAssertEqual(commits, 1)
    }

    func testOtherKeysAreLeftToTheField() {
        let coordinator = PhraseField.Coordinator(draft)
        let handled = coordinator.control(NSTextField(), textView: NSTextView(), doCommandBy: #selector(NSResponder.moveLeft(_:)))
        XCTAssertFalse(handled)
        XCTAssertEqual(commits, 0)
    }

    func testTypingStopsAtTheLimit() {
        let coordinator = PhraseField.Coordinator(draft)
        let field = NSTextField(string: String(repeating: "я", count: 300))
        coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        XCTAssertEqual(field.stringValue.count, Phrase.maxLength)
        XCTAssertEqual(draft.text.count, Phrase.maxLength)
    }
}
