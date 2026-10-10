import AppKit
import Carbon.HIToolbox
import OneThingCore

/// A global shortcut: a key code and Carbon modifier flags.
struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// From a key press while recording. Needs ⌘, ⌃ or ⌥, except for function keys.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        let code = UInt32(event.keyCode)
        guard Self.functionKeys.contains(code) || mods & UInt32(cmdKey | controlKey | optionKey) != 0 else { return nil }
        self.init(keyCode: code, modifiers: mods)
    }

    /// "⌃⌥⌘O"
    var display: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + Self.keyName(keyCode)
    }

    // MARK: Storage ("keyCode:modifiers"; nothing stored means no shortcut)

    static let key = "editShortcut"

    static func saved(in defaults: KeyValueStore = UserDefaults.standard) -> Shortcut? {
        guard let stored = defaults.string(forKey: key) else { return nil }
        let parts = stored.split(separator: ":").compactMap { UInt32($0) }
        return parts.count == 2 ? Shortcut(keyCode: parts[0], modifiers: parts[1]) : nil
    }

    static func save(_ shortcut: Shortcut?, in defaults: KeyValueStore = UserDefaults.standard) {
        if let shortcut {
            defaults.set("\(shortcut.keyCode):\(shortcut.modifiers)", forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: Key names

    private static let functionKeys: Set<UInt32> = Set([
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
        kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20,
    ].map(UInt32.init))

    private static let specialNames: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: L("Пробел"), kVK_Delete: "⌫", kVK_Escape: "⎋",
        kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_DownArrow: "↓", kVK_UpArrow: "↑",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_ANSI_KeypadEnter: "⌤",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7",
        kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12", kVK_F13: "F13",
        kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17", kVK_F18: "F18", kVK_F19: "F19",
        kVK_F20: "F20",
    ]

    /// The key's character on the current Latin layout, so letters read the same with a Russian layout on.
    static func keyName(_ keyCode: UInt32) -> String {
        if let name = specialNames[Int(keyCode)] { return name }
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return "?" }
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return data.withUnsafeBytes { raw -> String in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return "?" }
            var deadKeys: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                        UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                        &deadKeys, chars.count, &length, &chars)
            guard status == noErr, length > 0 else { return "?" }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }
}

/// The one global shortcut of the app: it opens the field for the phrase from any app. Carbon hot keys need no
/// permission. No shortcut is set until the user records one in Settings.
@MainActor
enum EditShortcut {
    private static var ref: EventHotKeyRef?
    private static var handler: EventHandlerRef?
    /// False when a shortcut is saved but the system would not give it: another app has it.
    private(set) static var isActive = false

    /// Registers the saved shortcut; call at launch and after every change.
    static func apply() {
        unregister()
        guard let shortcut = Shortcut.saved() else { return }
        if handler == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), editShortcutPressed, 1, &spec, nil, &handler)
        }
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
                                         EventHotKeyID(signature: OSType(0x4F4E_5448), id: 1), // 'ONTH'
                                         GetApplicationEventTarget(), 0, &newRef)
        isActive = status == noErr && newRef != nil
        ref = newRef
    }

    /// Frees the shortcut, for instance while Settings record a new one.
    static func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
        isActive = false
    }
}

private func editShortcutPressed(_: EventHandlerCallRef?, _: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    DispatchQueue.main.async {
        MainActor.assumeIsolated { StatusItem.shared.showPanel() }
    }
    return noErr
}
