import AppKit
import SwiftUI
import OneThingCore

/// «Шрифт» and, when the family has more than one face, «Начертание». The choice is saved at once; the menu bar item
/// and the field of the panel follow it (see `StatusItem.refresh`).
struct FontRows: View {
    @State private var choice = PhraseFont.effective(.saved())
    @State private var listOpen = false

    var body: some View {
        Row(title: L("Шрифт"),
            help: L("Шрифт фразы в строке меню и в поле ввода. Если выбранный шрифт пропадёт из системы, фраза вернётся к системному")) {
            FontCapsule(title: choice.isSystem ? L("Системный") : choice.family, open: $listOpen) {
                FontList(selected: choice.family, pick: pick)
            }
        }
        .onAppear { choice = PhraseFont.effective(.saved()) }
        if PhraseFont.styles(of: choice.family).count > 1 {
            Separator()
            Row(title: L("Начертание"), help: L("Какие начертания есть у выбранного шрифта: обычное, полужирное, курсив")) {
                MenuCapsule(title: choice.style.title, help: L("Начертание"), makeMenu: styleMenu)
            }
        }
    }

    private func pick(_ family: String) {
        update(FontChoice(family: family, style: choice.style))
        listOpen = false
    }

    private func styleMenu() -> NSMenu {
        let menu = NSMenu()
        for style in PhraseFont.styles(of: choice.family) {
            menu.addItem(ClosureMenuItem(style.title, checked: style == choice.style) {
                update(FontChoice(family: choice.family, style: style))
            })
        }
        return menu
    }

    /// Keeps the choice; a face the new family lacks becomes its regular one.
    private func update(_ next: FontChoice) {
        let kept = PhraseFont.effective(next)
        kept.save()
        choice = kept
    }
}

/// A value chosen from a list in a popover, as a capsule with a chevron, like `MenuCapsule`.
struct FontCapsule<Content: View>: View {
    let title: String
    @Binding var open: Bool
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        Button {
            open.toggle()
        } label: {
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Palette.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(Color.white.opacity(hovering ? 0.18 : 0.12)))
            .contentShape(Capsule())
        }
        .buttonStyle(PressStyle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .popover(isPresented: $open, arrowEdge: .bottom) { content }
        .accessibilityLabel(L("Шрифт"))
        .accessibilityValue(title)
    }
}

/// The installed families, each set in its own font, with a search field above them (the list is long). «Системный»
/// comes first; the list opens at the family in use.
struct FontList: View {
    let selected: String
    let pick: (String) -> Void
    @State private var query = ""
    @FocusState private var searching: Bool

    /// The search field shows when the list is longer than this.
    private static let searchFrom = 12
    private let families = PhraseFont.families

    private var matches: [String] {
        let words = query.trimmingCharacters(in: .whitespaces)
        return words.isEmpty ? families : families.filter { $0.localizedCaseInsensitiveContains(words) }
    }

    private var showsSystem: Bool {
        let words = query.trimmingCharacters(in: .whitespaces)
        return words.isEmpty || L("Системный").localizedCaseInsensitiveContains(words) || "System".localizedCaseInsensitiveContains(words)
    }

    var body: some View {
        VStack(spacing: 8) {
            if families.count > Self.searchFrom {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.secondary)
                    TextField(L("Поиск"), text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .focused($searching)
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Palette.control, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if showsSystem {
                            FontRow(title: L("Системный"), font: .system(size: 13), isSelected: selected.isEmpty) { pick("") }
                                .id("")
                        }
                        ForEach(matches, id: \.self) { family in
                            FontRow(title: family, font: Self.sample(family), isSelected: family == selected) { pick(family) }
                                .id(family)
                        }
                        if matches.isEmpty && !showsSystem {
                            Text(L("Ничего не найдено"))
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.secondary)
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                    }
                }
                .onAppear { proxy.scrollTo(selected, anchor: .center) }
            }
        }
        .padding(10)
        .frame(width: 250, height: 340)
        .background(Color.black)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .onAppear { searching = true }
    }

    /// The family's name in the family's own font, when that font has the letters for it and its lines are not so tall
    /// that they would push the rows apart; otherwise in the system font.
    private static func sample(_ family: String) -> Font {
        guard let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: 13),
              font.ascender - font.descender + font.leading <= 22,
              font.coveredCharacterSet.isSuperset(of: CharacterSet(charactersIn: family)) else { return .system(size: 13) }
        return Font(font as CTFont)
    }
}

private struct FontRow: View {
    let title: String
    let font: Font
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(font)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.secondary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(hovering ? 0.10 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
