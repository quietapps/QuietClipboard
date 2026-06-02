import SwiftUI
import SwiftData
import AppKit

@main
struct QuietClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator: AppCoordinator

    init() {
        let schema = Schema([ClipboardItem.self, Category.self])
        let storeURL = SharedStore.storeURL()
        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let coord = AppCoordinator(container: container)
            _coordinator = StateObject(wrappedValue: coord)
            Task { @MainActor in coord.bootstrap() }
        } catch {
            fatalError("SwiftData container failed: \(error)")
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

        Window("QC Bridge", id: "qc-bridge") {
            HiddenWindowBridge(coordinator: coordinator)
        }
        .defaultLaunchBehavior(.presented)
        .windowResizability(.contentSize)
        .commandsRemoved()

        Window("Quiet Clipboard", id: "library") {
            LibraryWindow()
                .environmentObject(coordinator)
                .environmentObject(coordinator.monitor)
                .modelContainer(coordinator.container)
        }
        .defaultSize(width: 1100, height: 720)
        .commands { CommandGroup(replacing: .newItem) {} }

        Settings {
            AppSettingsView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.monitor)
                .modelContainer(coordinator.container)
        }
    }

}

struct OpenWindowBridge: View {
    let coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                coordinator.setOpenWindowHandler { id in openWindow(id: id) }
            }
    }
}

struct HiddenWindowBridge: View {
    let coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .background(BridgeWindowHider())
            .onAppear {
                coordinator.setOpenWindowHandler { id in openWindow(id: id) }
            }
    }
}

private struct BridgeWindowHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let win = v.window else { return }
            win.alphaValue = 0
            win.ignoresMouseEvents = true
            win.isExcludedFromWindowsMenu = true
            win.setFrame(NSRect(x: -10000, y: -10000, width: 1, height: 1), display: false)
            win.collectionBehavior = [.transient, .ignoresCycle]
            win.standardWindowButton(.closeButton)?.isHidden = true
            win.standardWindowButton(.miniaturizeButton)?.isHidden = true
            win.standardWindowButton(.zoomButton)?.isHidden = true
            win.styleMask = [.borderless]
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let nc = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.willCloseNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didChangeOcclusionStateNotification
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
        DispatchQueue.main.async { [weak self] in self?.updateActivationPolicy() }
    }

    private func updateActivationPolicy() {
        let hasMainWindow = NSApp.windows.contains { w in
            guard w.isVisible, !(w is NSPanel), w.canBecomeMain else { return false }
            let cls = String(describing: type(of: w))
            if cls.contains("StatusBar") || cls.contains("MenuBarExtra") || cls.contains("PopupMenu") {
                return false
            }
            if w.identifier?.rawValue == "qc-bridge" { return false }
            if w.alphaValue == 0 { return false }
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

struct AppSettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var monitor: ClipboardMonitor

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            CaptureSettingsTab()
                .environmentObject(monitor)
                .tabItem { Label("Capture", systemImage: "doc.on.clipboard") }
            ShortcutSettingsTab(settings: coordinator.shortcutSettings, onChange: {
                coordinator.objectWillChange.send()
            })
            .tabItem { Label("Shortcuts", systemImage: "command") }
            StorageSettingsTab()
                .environmentObject(coordinator)
                .tabItem { Label("Storage", systemImage: "internaldrive") }
        }
        .frame(width: 580, height: 520)
    }

    private var generalTab: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { Preferences.launchAtLogin },
                    set: { Preferences.launchAtLogin = $0; coordinator.objectWillChange.send() }
                ))
                Toggle("Pause capture", isOn: Binding(
                    get: { monitor.isPaused },
                    set: { monitor.setPaused($0) }
                ))
            }
            Section("Quick search popup") {
                Picker("Open at", selection: Binding(
                    get: { Preferences.quickSearchPlacement },
                    set: { Preferences.quickSearchPlacement = $0; coordinator.objectWillChange.send() }
                )) {
                    ForEach(QuickSearchPlacement.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                Toggle("Show preview pane", isOn: Binding(
                    get: { Preferences.quickSearchPreviewEnabled },
                    set: { Preferences.quickSearchPreviewEnabled = $0; coordinator.objectWillChange.send() }
                ))
                Button("Reset popup size") {
                    coordinator.resetQuickSearchSize()
                }
                if Preferences.quickSearchPlacement == .screenCenterChosen {
                    Picker("Display", selection: Binding<CGDirectDisplayID>(
                        get: { Preferences.quickSearchDisplayID ?? primaryDisplayID() },
                        set: { Preferences.quickSearchDisplayID = $0; coordinator.objectWillChange.send() }
                    )) {
                        ForEach(NSScreen.screens, id: \.self) { s in
                            let id = (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
                            Text(s.localizedName).tag(CGDirectDisplayID(id))
                        }
                    }
                }
            }
            Section("About") {
                LabeledContent("Version",
                    value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")
            }
        }
        .formStyle(.grouped)
    }

    private func primaryDisplayID() -> CGDirectDisplayID {
        let id = (NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        return CGDirectDisplayID(id)
    }
}
