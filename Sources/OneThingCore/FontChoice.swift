import Foundation

/// The faces a phrase can be set in.
public enum FontStyle: String, CaseIterable {
    case regular, bold, italic, boldItalic

    public var isBold: Bool { self == .bold || self == .boldItalic }
    public var isItalic: Bool { self == .italic || self == .boldItalic }

    public init(bold: Bool, italic: Bool) {
        self = bold ? (italic ? .boldItalic : .bold) : (italic ? .italic : .regular)
    }
}

/// The font of the phrase as Settings keeps it: a family by name (empty means the system font) and a face. Whether the
/// family is still installed is for AppKit to say (`PhraseFont`); the choice stays as it was while the font is away.
public struct FontChoice: Equatable {
    public static let familyKey = "fontFamily"
    public static let styleKey = "fontStyle"
    public static let system = FontChoice()

    public var family: String
    public var style: FontStyle

    public init(family: String = "", style: FontStyle = .regular) {
        self.family = family
        self.style = style
    }

    public var isSystem: Bool { family.isEmpty }

    public static func saved(in defaults: KeyValueStore = UserDefaults.standard) -> FontChoice {
        FontChoice(family: defaults.string(forKey: familyKey) ?? "",
                   style: defaults.string(forKey: styleKey).flatMap(FontStyle.init(rawValue:)) ?? .regular)
    }

    /// The system font and the regular face are the defaults, so they are stored as nothing.
    public func save(in defaults: KeyValueStore = UserDefaults.standard) {
        if isSystem {
            defaults.removeObject(forKey: Self.familyKey)
        } else {
            defaults.set(family, forKey: Self.familyKey)
        }
        if style == .regular {
            defaults.removeObject(forKey: Self.styleKey)
        } else {
            defaults.set(style.rawValue, forKey: Self.styleKey)
        }
    }
}
