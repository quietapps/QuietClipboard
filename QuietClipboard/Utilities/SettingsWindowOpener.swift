import AppKit
import SwiftUI

@MainActor
enum SettingsWindowOpener {
    static func open(openSettings: OpenSettingsAction? = nil) {
        NSApp.activate(ignoringOtherApps: true)
        if let win = NSApp.windows.first(where: isSettingsWindow) {
            win.makeKeyAndOrderFront(nil)
            return
        }
        if let openSettings {
            openSettings()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let win = NSApp.windows.first(where: isSettingsWindow) {
                win.makeKeyAndOrderFront(nil)
            }
        }
    }

    private static func isSettingsWindow(_ win: NSWindow) -> Bool {
        let id = win.identifier?.rawValue ?? ""
        if id.lowercased().contains("settings") || id.lowercased().contains("preferences") {
            return true
        }
        let title = win.title.lowercased()
        return title.contains("settings") || title.contains("preferences")
    }
}
