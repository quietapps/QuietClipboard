import AppKit
import ApplicationServices

enum AccessibilityPermissionHelper {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system dialog to add Quiet Clipboard to Accessibility.
    static func requestPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
