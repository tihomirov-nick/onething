import AppKit
import SwiftUI
import OneThingCore

/// What the field of the panel holds while the panel is open.
@MainActor
final class PhraseDraft: ObservableObject {
    static let shared = PhraseDraft()

    private let store: KeyValueStore
    @Published var text: String
    /// The font of the phrase at the size of the menu bar text, so the field shows how the phrase will look.
    @Published var font: NSFont
    /// What follows Return: the menu bar item shows the phrase and the panel closes.
    var didCommit: () -> Void = {
        StatusItem.shared.refresh()
        StatusItem.shared.dismissPanel()
    }

    init(store: KeyValueStore = UserDefaults.standard) {
        self.store = store
        text = Phrase.saved(in: store)
        font = PhraseFont.current(size: PhraseFont.size, in: store)
    }

    /// The panel has just opened: the saved phrase and the chosen font are back. What was typed and abandoned (Esc, a click
    /// elsewhere) is gone.
    func reload() {
        text = Phrase.saved(in: store)
        font = PhraseFont.current(size: PhraseFont.size, in: store)
    }

    /// Return: the phrase is kept, cleaned up; an empty field removes it and the menu bar shows the mark again.
    func commit() {
        text = Phrase.save(text, in: store)
        didCommit()
    }
}

/// A single-line field that takes the keyboard each time its window becomes the key window, with the whole phrase
/// selected: the panel does not bring the app forward, so the field must ask for the keyboard itself.
final class PhraseTextField: NSTextField {
    weak var draft: PhraseDraft?

    override var font: NSFont? {
        didSet { invalidateIntrinsicContentSize() }
    }

    /// The height of one line of the font; the width is the layout's to give, whatever the text is.
    override var intrinsicContentSize: NSSize {
        let height = font.map { $0.ascender - $0.descender + $0.leading } ?? 16
        return NSSize(width: NSView.noIntrinsicMetric, height: ceil(height))
    }

    /// The font of the field and of the hint shown while it is empty.
    func setFont(_ font: NSFont, placeholder: String) {
        self.font = font
        placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
            .font: font, .foregroundColor: NSColor.white.withAlphaComponent(0.4),
        ])
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        guard let window else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(windowBecameKey), name: NSWindow.didBecomeKeyNotification,
                                               object: window)
        // The window may have become key before the field was there (the first time the panel opens).
        if window.isKeyWindow {
            DispatchQueue.main.async { [weak self] in
                self?.windowBecameKey(Notification(name: NSWindow.didBecomeKeyNotification, object: window))
            }
        }
    }

    @objc private func windowBecameKey(_ notification: Notification) {
        if let draft {
            draft.reload()
            stringValue = draft.text
            setFont(draft.font, placeholder: placeholderAttributedString?.string ?? "")
        }
        // The window finishes becoming key first; then the field takes the keyboard.
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, window.isVisible else { return }
            window.makeFirstResponder(self)
            self.selectText(nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

/// The field for the phrase: Return keeps it, Esc (the panel's own key) closes the panel without keeping the changes.
struct PhraseField: NSViewRepresentable {
    @ObservedObject var draft: PhraseDraft
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(draft)
    }

    func makeNSView(context: Context) -> PhraseTextField {
        let field = PhraseTextField()
        field.draft = draft
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.textColor = .white
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
        field.cell?.isScrollable = true
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setFont(draft.font, placeholder: placeholder)
        field.stringValue = draft.text
        field.setAccessibilityLabel(placeholder)
        return field
    }

    func updateNSView(_ field: PhraseTextField, context: Context) {
        if field.font != draft.font { field.setFont(draft.font, placeholder: placeholder) }
        if field.stringValue != draft.text { field.stringValue = draft.text }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        let draft: PhraseDraft

        init(_ draft: PhraseDraft) {
            self.draft = draft
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            let kept = Phrase.limited(field.stringValue)
            if kept != field.stringValue { field.stringValue = kept }
            draft.text = kept
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            draft.commit()
            return true
        }
    }
}
