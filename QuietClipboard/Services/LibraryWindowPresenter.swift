import AppKit
import SwiftUI
import SwiftData

/// Presents the library in a standard `NSWindow` so it opens from Quick Search, shortcuts, and the menu bar
/// without relying on SwiftUI `openWindow` from the menu bar scene.
@MainActor
final class LibraryWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = LibraryWindowPresenter()

    private var window: NSWindow?

    func present(coordinator: AppCoordinator) {
        if let window {
            show(window)
            return
        }

        let root = LibraryWindow()
            .environmentObject(coordinator)
            .environmentObject(coordinator.monitor)
            .modelContainer(coordinator.container)

        let host = NSHostingController(rootView: root)
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Quiet Clipboard"
        w.identifier = NSUserInterfaceItemIdentifier("library")
        w.contentViewController = host
        w.setFrameAutosaveName("QuietClipboardLibrary")
        w.delegate = self
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 900, height: 600)
        w.center()

        window = w
        show(w)
    }

    private func show(_ window: NSWindow) {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        (notification.object as? NSWindow)?.orderOut(nil)
    }
}
