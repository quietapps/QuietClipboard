import AppKit
import Carbon.HIToolbox

enum PasteSimulator {
    private static let charDelay: TimeInterval = 0.0015

    /// Invoked (on main) when an automatic paste can't run because Accessibility isn't granted.
    /// The clip is already on the pasteboard, so the user can paste manually; this is for guidance.
    @MainActor static var onAccessibilityNeeded: (() -> Void)?

    static func plainText(from item: ClipboardItem) -> String? {
        item.resolvedText
    }

    /// True when we can synthesize keystrokes. If not, fires `onAccessibilityNeeded` so the app
    /// can guide the user instead of silently doing nothing.
    @MainActor private static func ensureAccessibility() -> Bool {
        if AccessibilityPermissionHelper.isGranted { return true }
        onAccessibilityNeeded?()
        return false
    }

    /// Sends ⌘V after activating the target app (pasteboard must already contain the clip).
    /// `afterPaste` runs shortly after the keystroke — used to restore the prior clipboard.
    static func performPaste(priorApp: NSRunningApplication?, afterPaste: (() -> Void)? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            priorApp?.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard ensureAccessibility() else { return }   // leave clip on pasteboard for manual paste
                postCommandV()
                if let afterPaste {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: afterPaste)
                }
            }
        }
    }

    static func pasteAndRestore(item: ClipboardItem, priorApp: NSRunningApplication?) {
        PasteboardHelper.write(item, to: .general)
        performPaste(priorApp: priorApp)
    }

    /// Types plain text character-by-character for apps that block paste (banking, RDP).
    static func typeIntoApp(_ text: String, priorApp: NSRunningApplication?) {
        priorApp?.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard ensureAccessibility() else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                typeTextSynchronously(text)
            }
        }
    }

    static func postCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// The app to paste into. If our own window is frontmost (e.g. the Library is open), falls back
    /// to the last external app so paste-by-index / multi-paste don't paste into ourselves.
    @MainActor static func capturedFrontmost() -> NSRunningApplication? {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier == Bundle.main.bundleIdentifier {
            return FrontmostAppTracker.shared.lastExternalApp ?? front
        }
        return front
    }

    private static func typeTextSynchronously(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
            ?? CGEventSource(stateID: .hidSystemState)
        for char in text {
            switch char {
            case "\n", "\r":
                postKey(CGKeyCode(kVK_Return), source: source, keyDown: true)
                postKey(CGKeyCode(kVK_Return), source: source, keyDown: false)
            case "\t":
                postKey(CGKeyCode(kVK_Tab), source: source, keyDown: true)
                postKey(CGKeyCode(kVK_Tab), source: source, keyDown: false)
            default:
                postUnicode(String(char), source: source)
            }
            if charDelay > 0 {
                Thread.sleep(forTimeInterval: charDelay)
            }
        }
    }

    private static func postUnicode(_ string: String, source: CGEventSource?) {
        var utf16 = Array(string.utf16)
        guard !utf16.isEmpty else { return }
        let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
        down?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        up?.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
        up?.post(tap: .cghidEventTap)
    }

    private static func postKey(_ keyCode: CGKeyCode, source: CGEventSource?, keyDown: Bool) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
        event?.post(tap: .cghidEventTap)
    }
}
