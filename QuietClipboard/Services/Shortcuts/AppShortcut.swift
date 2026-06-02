import Foundation
import AppKit
import Carbon.HIToolbox

enum AppShortcutAction: String, CaseIterable, Identifiable, Codable {
    case openQuickSearch
    case openLibrary
    case toggleCapture
    case pasteClip0
    case pasteClip1
    case pasteClip2
    case pasteClip3
    case pasteClip4
    case pasteClip5
    case pasteClip6
    case pasteClip7
    case pasteClip8
    case pasteClip9

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openQuickSearch: return "Open Quick Search"
        case .openLibrary: return "Open Library"
        case .toggleCapture: return "Toggle Capture"
        case .pasteClip0: return "Paste Clip 1"
        case .pasteClip1: return "Paste Clip 2"
        case .pasteClip2: return "Paste Clip 3"
        case .pasteClip3: return "Paste Clip 4"
        case .pasteClip4: return "Paste Clip 5"
        case .pasteClip5: return "Paste Clip 6"
        case .pasteClip6: return "Paste Clip 7"
        case .pasteClip7: return "Paste Clip 8"
        case .pasteClip8: return "Paste Clip 9"
        case .pasteClip9: return "Paste Clip 10"
        }
    }

    var pasteIndex: Int? {
        switch self {
        case .pasteClip0: return 0
        case .pasteClip1: return 1
        case .pasteClip2: return 2
        case .pasteClip3: return 3
        case .pasteClip4: return 4
        case .pasteClip5: return 5
        case .pasteClip6: return 6
        case .pasteClip7: return 7
        case .pasteClip8: return 8
        case .pasteClip9: return 9
        default: return nil
        }
    }

    static var defaults: [AppShortcutAction: KeyCombo] {
        let ctrlCmd: NSEvent.ModifierFlags = [.control, .command]
        return [
            .openQuickSearch: KeyCombo(keyCode: UInt32(kVK_ANSI_V), modifiers: ctrlCmd),
            .openLibrary: KeyCombo(keyCode: UInt32(kVK_ANSI_L), modifiers: ctrlCmd),
            .toggleCapture: KeyCombo(keyCode: UInt32(kVK_ANSI_P), modifiers: ctrlCmd),
            .pasteClip0: KeyCombo(keyCode: UInt32(kVK_ANSI_1), modifiers: ctrlCmd),
            .pasteClip1: KeyCombo(keyCode: UInt32(kVK_ANSI_2), modifiers: ctrlCmd),
            .pasteClip2: KeyCombo(keyCode: UInt32(kVK_ANSI_3), modifiers: ctrlCmd),
            .pasteClip3: KeyCombo(keyCode: UInt32(kVK_ANSI_4), modifiers: ctrlCmd),
            .pasteClip4: KeyCombo(keyCode: UInt32(kVK_ANSI_5), modifiers: ctrlCmd),
            .pasteClip5: KeyCombo(keyCode: UInt32(kVK_ANSI_6), modifiers: ctrlCmd),
            .pasteClip6: KeyCombo(keyCode: UInt32(kVK_ANSI_7), modifiers: ctrlCmd),
            .pasteClip7: KeyCombo(keyCode: UInt32(kVK_ANSI_8), modifiers: ctrlCmd),
            .pasteClip8: KeyCombo(keyCode: UInt32(kVK_ANSI_9), modifiers: ctrlCmd),
            .pasteClip9: KeyCombo(keyCode: UInt32(kVK_ANSI_0), modifiers: ctrlCmd),
        ]
    }
}

struct KeyCombo: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifierBits: UInt

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierBits = modifiers.rawValue
    }

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierBits)
    }

    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        let mods = modifiers
        if mods.contains(.command) { m |= UInt32(cmdKey) }
        if mods.contains(.option) { m |= UInt32(optionKey) }
        if mods.contains(.control) { m |= UInt32(controlKey) }
        if mods.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    var displayString: String {
        var parts: [String] = []
        let mods = modifiers
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        parts.append(KeyCombo.keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for code: UInt32) -> String {
        switch Int(code) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Escape: return "⎋"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: return "?"
        }
    }
}

final class ShortcutSettings: ObservableObject {
    @Published private(set) var bindings: [AppShortcutAction: KeyCombo]
    private let key = "QuietClipboard.Shortcuts"

    init() {
        if let data = UserDefaults.standard.data(forKey: "QuietClipboard.Shortcuts"),
           let decoded = try? JSONDecoder().decode([String: KeyCombo].self, from: data) {
            var out: [AppShortcutAction: KeyCombo] = [:]
            for (k, v) in decoded {
                if let action = AppShortcutAction(rawValue: k) { out[action] = v }
            }
            bindings = AppShortcutAction.defaults.merging(out) { _, b in b }
        } else {
            bindings = AppShortcutAction.defaults
        }
    }

    func set(_ combo: KeyCombo?, for action: AppShortcutAction) {
        if let combo {
            bindings[action] = combo
        } else {
            bindings.removeValue(forKey: action)
        }
        persist()
    }

    func resetToDefaults() {
        bindings = AppShortcutAction.defaults
        persist()
    }

    private func persist() {
        let raw = bindings.reduce(into: [String: KeyCombo]()) { $0[$1.key.rawValue] = $1.value }
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
