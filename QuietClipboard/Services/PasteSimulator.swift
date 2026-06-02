import AppKit
import Carbon.HIToolbox

enum PasteSimulator {
    static func pasteAndRestore(item: ClipboardItem, priorApp: NSRunningApplication?) {
        PasteboardHelper.write(item, to: .general)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            priorApp?.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                postCommandV()
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

    static func capturedFrontmost() -> NSRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }
}
