import AppKit
import Carbon.HIToolbox
import SwiftUI
import OneThingCore

// The places where an app made from the template becomes itself. The rest of Sources/OneThing is the family's
// plumbing: the icon with its menu and panel, Settings, updates, the interface language and the sounds. The phrase itself
// is in PhraseField.swift, its font in PhraseFont.swift and FontPicker.swift, how the menu bar draws it in MenuBarText.swift.

// MARK: - 1. The glyph

extension MenuBarIcon {
    /// The mark in the menu bar, shown while there is no phrase (or the text is hidden): an opening double quotation mark,
    /// two solid shapes (OneThing.swift, with the conventions of Glyph.swift), 20 pt tall on the 22 pt canvas.
    /// scripts/make_icon.swift draws the same mark on the app icon. The mark places itself in the canvas of the image, so
    /// `box` stays unused.
    static func drawGlyph(in ctx: CGContext, box: CGRect) {
        ctx.saveGState()
        Glyph.enterMenuBox(ctx, bounds: OneThing.bounds, scale: max(1, abs(ctx.ctm.a)))
        OneThing.draw(ctx)
        ctx.restoreGState()
    }
}

// MARK: - 2. The main view

/// The field for the phrase, in the black panel under the icon (a left click). Return keeps the phrase, Esc closes the
/// panel. The field is set in the font chosen in Settings, so it shows how the phrase will look in the menu bar.
struct MainView: View {
    @ObservedObject private var draft = PhraseDraft.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhraseField(draft: draft, placeholder: L("Одно дело на сегодня"))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Palette.control, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .help(L("Пустая фраза возвращает в строку меню знак"))
            Text(L("Return сохраняет, Esc закрывает"))
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.secondary)
                .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 3. The app's section in Settings

/// «Фраза»: the width of the text in the menu bar, hiding it, the font and the shortcut that opens the field.
struct AppSettingsSection: View {
    @AppStorage(Phrase.maxWidthKey) private var maxWidth = Phrase.defaultWidth
    @AppStorage(Phrase.hideTextKey) private var hideText = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.gap) {
            SectionTitle(L("Фраза"))
            VStack(spacing: 0) {
                Row(title: L("Максимальная ширина"),
                    help: L("Фраза длиннее обрезается с многоточием. Целиком она видна в подсказке к значку и в окошке")) {
                    MenuCapsule(title: widthTitle(maxWidth), help: L("Максимальная ширина"), makeMenu: widthMenu)
                }
                Separator()
                SwitchRow(title: L("Скрыть текст"),
                          help: L("В строке меню остаётся только знак. Фраза сохраняется и видна в окошке по щелчку"),
                          isOn: $hideText)
                Separator()
                FontRows()
                Separator()
                ShortcutRows()
            }
            .card()
        }
    }

    private func widthTitle(_ width: Double) -> String {
        "\(Int(width)) pt"
    }

    private func widthMenu() -> NSMenu {
        let menu = NSMenu()
        for width in Phrase.widthChoices {
            menu.addItem(ClosureMenuItem(widthTitle(width), checked: width == maxWidth) { maxWidth = width })
        }
        return menu
    }
}

/// The shortcut that opens the field from any app: a capsule that records the next key combination. Nothing is set until
/// the user records one.
private struct ShortcutRows: View {
    @State private var shortcut = Shortcut.saved()
    @State private var recording = false
    @State private var monitor: Any?
    @State private var hovering = false
    @State private var taken = false

    var body: some View {
        Row(title: L("Сочетание для правки"),
            help: L("Это сочетание открывает поле для фразы в любом приложении. Нажмите на него и введите новое. Esc отменяет, ⌫ убирает сочетание")) {
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? L("Нажмите сочетание…") : (shortcut?.display ?? L("Не задано")))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(recording || shortcut != nil ? Color.white : Palette.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(minWidth: 70, minHeight: 24, maxHeight: 24)
                    .background(Capsule().fill(Color.white.opacity(recording ? 0.24 : (hovering ? 0.18 : 0.12))))
                    .contentShape(Capsule())
            }
            .buttonStyle(PressStyle())
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
        }
        .onAppear(perform: refresh)
        .onDisappear { stop() }
        if taken {
            Separator()
            NoteRow(text: L("Это сочетание занято другим приложением")) { EmptyView() }
        }
    }

    private func start() {
        recording = true
        // Free the shortcut, so pressing it records it instead of opening the field.
        EditShortcut.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                stop()
            case kVK_Delete, kVK_ForwardDelete:
                set(nil)
            default:
                if let new = Shortcut(event: event) {
                    set(new)
                } else {
                    NSSound.beep()
                }
            }
            return nil
        }
    }

    private func stop() {
        guard recording || monitor != nil else { return }
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        EditShortcut.apply()
        refresh()
    }

    private func set(_ new: Shortcut?) {
        shortcut = new
        Shortcut.save(new)
        stop()
    }

    private func refresh() {
        shortcut = Shortcut.saved()
        taken = shortcut != nil && !EditShortcut.isActive
    }
}

// MARK: - 4. The actions of the menu and 5. being busy

@MainActor
enum AppActions {
    /// The app's actions at the top of the menu of the icon (right click or Control-click), above «Настройки…»; the
    /// menu adds the separator. `ClosureMenuItem` makes an item from a closure. None here: the menu is the standard one.
    static func menuItems() -> [NSMenuItem] {
        []
    }

    /// The app is in the middle of something a restart would break: the field for the phrase is open. An update that
    /// installs itself waits until this says no, and so does «Перезапустить» for a new interface language.
    static var isBusy: Bool {
        StatusItem.shared.panelIsVisible
    }
}
