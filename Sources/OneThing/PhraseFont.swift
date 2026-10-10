import AppKit
import OneThingCore

/// The font of the phrase as AppKit has it: the system font or an installed family, in one of four faces. What is gone
/// falls back quietly: a family that has left the Mac to the system font, a face the family no longer has to its
/// regular one. The choice itself stays as it was, so a font that comes back is used again.
enum PhraseFont {
    /// The size of the menu bar's own text. The phrase is set in it in the menu bar and in the field of the panel.
    static var size: CGFloat { NSFont.menuBarFont(ofSize: 0).pointSize }

    /// The installed families, in the order the system gives them.
    static var families: [String] { NSFontManager.shared.availableFontFamilies }

    static func isInstalled(_ family: String) -> Bool {
        !(NSFontManager.shared.availableMembers(ofFontFamily: family) ?? []).isEmpty
    }

    /// The faces `family` has among the four; the system font has all of them.
    static func styles(of family: String) -> [FontStyle] {
        if family.isEmpty { return FontStyle.allCases }
        return FontStyle.allCases.filter { face(of: family, style: $0, size: 13) != nil }
    }

    /// What a choice comes to on this Mac: a family that is gone is the system font, a face the family lacks is its
    /// regular one.
    static func effective(_ choice: FontChoice) -> FontChoice {
        guard !choice.isSystem else { return choice }
        guard isInstalled(choice.family) else { return .system }
        let styles = styles(of: choice.family)
        if styles.contains(choice.style) { return choice }
        return FontChoice(family: choice.family, style: styles.contains(.regular) ? .regular : (styles.first ?? .regular))
    }

    static func font(for choice: FontChoice, size: CGFloat) -> NSFont {
        let choice = effective(choice)
        if choice.isSystem { return system(choice.style, size: size) }
        return face(of: choice.family, style: choice.style, size: size)
            ?? NSFontManager.shared.font(withFamily: choice.family, traits: [], weight: 5, size: size)
            ?? system(.regular, size: size)
    }

    /// The saved choice, set in `size`.
    static func current(size: CGFloat, in store: KeyValueStore = UserDefaults.standard) -> NSFont {
        font(for: .saved(in: store), size: size)
    }

    /// The system font as the menu bar sets it, in a face.
    private static func system(_ style: FontStyle, size: CGFloat) -> NSFont {
        let manager = NSFontManager.shared
        var font = NSFont.menuBarFont(ofSize: size)
        if style.isBold { font = manager.convert(font, toHaveTrait: .boldFontMask) }
        if style.isItalic { font = manager.convert(font, toHaveTrait: .italicFontMask) }
        return font
    }

    /// The face of `family` that is bold or not and italic or not as asked, nil when the family has no such face.
    private static func face(of family: String, style: FontStyle, size: CGFloat) -> NSFont? {
        let manager = NSFontManager.shared
        var traits: NSFontTraitMask = style.isBold ? .boldFontMask : .unboldFontMask
        traits.formUnion(style.isItalic ? .italicFontMask : .unitalicFontMask)
        guard let font = manager.font(withFamily: family, traits: traits, weight: style.isBold ? 9 : 5, size: size) else { return nil }
        // The manager may hand back the nearest face; only the one asked for counts.
        let have = manager.traits(of: font)
        let bold = have.contains(.boldFontMask) || manager.weight(of: font) >= 9
        return bold == style.isBold && have.contains(.italicFontMask) == style.isItalic ? font : nil
    }
}

extension FontStyle {
    var title: String {
        switch self {
        case .regular: return L("Обычное")
        case .bold: return L("Полужирное")
        case .italic: return L("Курсив")
        case .boldItalic: return L("Полужирный курсив")
        }
    }
}
