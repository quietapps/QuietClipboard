import SwiftUI
import SwiftData
import AppKit

@main
struct QuietClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator: AppCoordinator

    init() {
        let schema = Schema([ClipboardItem.self, Category.self, ClipboardCopyEvent.self])
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
                .background {
                    WindowHandlerInstaller(coordinator: coordinator)
                }
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
        .frame(width: 620, height: 580)
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
            Section("Appearance") {
                Picker("List previews", selection: Binding(
                    get: { Preferences.clipPreviewStyle },
                    set: {
                        Preferences.clipPreviewStyle = $0
                        coordinator.objectWillChange.send()
                    }
                )) {
                    ForEach(ClipPreviewStyle.allCases) { style in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(style.displayName)
                            Text(style.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(style)
                    }
                }
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
                Toggle("Show Preview", isOn: Binding(
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
            Section("Popup filter bar") {
                Text("Choose which filters appear in the Quick Search popup.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(QuickSearchPopupFilter.allCases) { filter in
                    Toggle(isOn: quickSearchFilterBinding(filter)) {
                        Label(filter.displayName, systemImage: filter.systemImage)
                    }
                }
                Toggle("Show my categories", isOn: Binding(
                    get: { QuickSearchFilterPreferences.showUserCategories },
                    set: {
                        QuickSearchFilterPreferences.showUserCategories = $0
                        coordinator.objectWillChange.send()
                    }
                ))
                Button("Reset filters to defaults") {
                    QuickSearchFilterPreferences.resetToDefaults()
                    coordinator.objectWillChange.send()
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

    private func quickSearchFilterBinding(_ filter: QuickSearchPopupFilter) -> Binding<Bool> {
        Binding(
            get: { QuickSearchFilterPreferences.isEnabled(filter) },
            set: { enabled in
                var filters = QuickSearchFilterPreferences.enabledFilters
                if enabled {
                    filters.insert(filter)
                } else {
                    filters.remove(filter)
                }
                QuickSearchFilterPreferences.enabledFilters = filters
                coordinator.objectWillChange.send()
            }
        )
    }
}
