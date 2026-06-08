import SwiftUI
import SwiftData
import AppKit

@main
struct QuietClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator: AppCoordinator

    init() {
        let schema = Schema([ClipboardItem.self, Category.self, ClipboardCopyEvent.self])
        let result = StoreBootstrap.makeContainer(schema: schema)
        let coord = AppCoordinator(container: result.container)
        _coordinator = StateObject(wrappedValue: coord)
        let recoveryMessage = result.recoveryMessage
        Task { @MainActor in
            coord.bootstrap()
            if let recoveryMessage {
                StoreBootstrap.presentRecoveryAlert(recoveryMessage)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopover()
                .environmentObject(coordinator)
                .environmentObject(coordinator.monitor)
                .modelContainer(coordinator.container)
        } label: {
            Image(systemName: coordinator.isPaused
                  ? "doc.on.clipboard"
                  : "doc.on.clipboard.fill")
        }
        .menuBarExtraStyle(.window)

        .commands { CommandGroup(replacing: .newItem) {} }

        Settings {
            AppSettingsView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.monitor)
                .modelContainer(coordinator.container)
        }
    }

}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var observers: [NSObjectProtocol] = []
    private var activationUpdatePending = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let nc = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.willCloseNotification
        ]
        for name in names {
            let obs = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleActivationUpdate()
            }
            observers.append(obs)
        }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    private func scheduleActivationUpdate() {
        guard !activationUpdatePending else { return }
        activationUpdatePending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.activationUpdatePending = false
            self.updateActivationPolicy()
        }
    }

    private func updateActivationPolicy() {
        let hasMainWindow = NSApp.windows.contains { w in
            guard w.isVisible, !(w is NSPanel), w.canBecomeMain else { return false }
            let cls = String(describing: type(of: w))
            if cls.contains("StatusBar") || cls.contains("MenuBarExtra") || cls.contains("PopupMenu") {
                return false
            }
            if w.alphaValue == 0 { return false }
            if w.frame.width < 80 || w.frame.height < 80 { return false }
            return true
        }
        let target: NSApplication.ActivationPolicy = hasMainWindow ? .regular : .accessory
        if NSApp.activationPolicy() != target {
            NSApp.setActivationPolicy(target)
            if target == .regular {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

