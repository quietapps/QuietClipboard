import SwiftUI
import AppKit

struct AppSettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var monitor: ClipboardMonitor
    @State private var panel: SettingsPanel = .general

    var body: some View {
        SettingsShell(panel: $panel) {
            Group {
                switch panel {
                case .general:
                    GeneralSettingsPanel()
                        .environmentObject(coordinator)
                        .environmentObject(monitor)
                case .quickSearch:
                    QuickSearchSettingsPanel()
                        .environmentObject(coordinator)
                case .capture:
                    CaptureSettingsTab()
                        .environmentObject(monitor)
                case .shortcuts:
                    ShortcutSettingsTab(
                        settings: coordinator.shortcutSettings,
                        onChange: { coordinator.objectWillChange.send() }
                    )
                case .statistics:
                    StatisticsSettingsTab()
                        .environmentObject(coordinator)
                case .storage:
                    StorageSettingsTab()
                        .environmentObject(coordinator)
                case .about:
                    AboutSettingsPanel()
                }
            }
        }
        .frame(minWidth: 620, idealWidth: 720, minHeight: 480)
        .background(SettingsWindowConfigurator())
    }
}

/// Ensures the system Settings window stays user-resizable.
private struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configureSettingsWindow(from: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configureSettingsWindow(from: nsView) }
    }

    private func configureSettingsWindow(from view: NSView) {
        guard let window = view.window ?? NSApp.windows.first(where: isSettingsWindow) else { return }
        window.styleMask.insert([.resizable, .fullSizeContentView])
        if window.minSize.width < 620 {
            window.minSize = NSSize(width: 620, height: 480)
        }
    }

    private func isSettingsWindow(_ window: NSWindow) -> Bool {
        let id = window.identifier?.rawValue.lowercased() ?? ""
        if id.contains("settings") || id.contains("preferences") { return true }
        let title = window.title.lowercased()
        return title.contains("settings") || title.contains("preferences")
    }
}

// MARK: - General

private struct GeneralSettingsPanel: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var monitor: ClipboardMonitor

    var body: some View {
        SettingsScrollContent {
            SettingsCard(
                title: "App",
                systemImage: "macwindow",
                footer: "Sound plays when a new clip is saved; a lower tone plays for sensitive captures."
            ) {
                SettingsToggleRow(
                    title: "Launch at login",
                    isOn: Binding(
                        get: { Preferences.launchAtLogin },
                        set: {
                            Preferences.launchAtLogin = $0
                            coordinator.objectWillChange.send()
                        }
                    )
                )
                SettingsInsetDivider()
                SettingsToggleRow(
                    title: "Pause capture",
                    subtitle: "Stops saving new clips until resumed",
                    isOn: Binding(
                        get: { monitor.isPaused },
                        set: { monitor.setPaused($0) }
                    )
                )
                SettingsInsetDivider()
                SettingsToggleRow(
                    title: "Sound on capture",
                    isOn: Binding(
                        get: { Preferences.soundOnCopy },
                        set: { Preferences.soundOnCopy = $0 }
                    )
                )
            }

            SettingsCard(
                title: "Paste",
                systemImage: "arrow.right.doc.on.clipboard",
                footer: "Auto-type sends keystrokes for apps that block paste (banking, RDP)."
            ) {
                SettingsPickerRow(
                    title: "Default paste method",
                    selection: Binding(
                        get: { Preferences.pasteDeliveryMethod },
                        set: {
                            Preferences.pasteDeliveryMethod = $0
                            coordinator.objectWillChange.send()
                        }
                    )
                ) {
                    ForEach(PasteDeliveryMethod.allCases) { method in
                        Text(method.displayName).tag(method)
                    }
                }
            }

            SettingsCard(title: "Appearance", systemImage: "paintbrush") {
                SettingsPickerRow(
                    title: "List previews",
                    selection: Binding(
                        get: { Preferences.clipPreviewStyle },
                        set: {
                            Preferences.clipPreviewStyle = $0
                            coordinator.objectWillChange.send()
                        }
                    )
                ) {
                    ForEach(ClipPreviewStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                ForEach(ClipPreviewStyle.allCases) { style in
                    if style == Preferences.clipPreviewStyle {
                        SettingsCaption(style.detail)
                    }
                }
            }
        }
    }
}

// MARK: - Quick Search

private struct QuickSearchSettingsPanel: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var quickSearchListLimitText = "\(Preferences.quickSearchListLimitDefault)"
    @FocusState private var quickSearchListLimitFocused: Bool

    var body: some View {
        SettingsScrollContent {
            SettingsCard(
                title: "Popup",
                systemImage: "rectangle.center.inset.filled",
                footer: "Maximum clips shown when browsing or searching in Quick Search. Default \(Preferences.quickSearchListLimitDefault), up to \(Preferences.quickSearchListLimitMax). Older clips stay in the Library."
            ) {
                SettingsLabeledFieldRow(title: "Clips in list") {
                    SettingsMonospaceField(text: $quickSearchListLimitText)
                        .focused($quickSearchListLimitFocused)
                        .onSubmit(commitQuickSearchListLimit)
                        .onChange(of: quickSearchListLimitFocused) { _, focused in
                            if !focused { commitQuickSearchListLimit() }
                        }
                }

                SettingsInsetDivider()

                SettingsPickerRow(
                    title: "Open at",
                    selection: Binding(
                        get: { Preferences.quickSearchPlacement },
                        set: {
                            Preferences.quickSearchPlacement = $0
                            coordinator.objectWillChange.send()
                        }
                    )
                ) {
                    ForEach(QuickSearchPlacement.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }

                SettingsInsetDivider()

                SettingsToggleRow(
                    title: "Show preview",
                    isOn: Binding(
                        get: { Preferences.quickSearchPreviewEnabled },
                        set: {
                            Preferences.quickSearchPreviewEnabled = $0
                            coordinator.objectWillChange.send()
                        }
                    )
                )

                SettingsInsetDivider()

                SettingsActionButton(title: "Reset popup size", systemImage: "arrow.counterclockwise") {
                    coordinator.resetQuickSearchSize()
                }

                if Preferences.quickSearchPlacement == .screenCenterChosen {
                    SettingsInsetDivider()
                    SettingsPickerRow(
                        title: "Display",
                        selection: Binding<CGDirectDisplayID>(
                            get: { Preferences.quickSearchDisplayID ?? primaryDisplayID() },
                            set: {
                                Preferences.quickSearchDisplayID = $0
                                coordinator.objectWillChange.send()
                            }
                        )
                    ) {
                        ForEach(NSScreen.screens, id: \.self) { s in
                            let id = (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
                            Text(s.localizedName).tag(CGDirectDisplayID(id))
                        }
                    }
                }
            }

            SettingsCard(
                title: "Filter bar",
                systemImage: "line.3.horizontal.decrease.circle",
                footer: "Choose which filters appear in the Quick Search popup."
            ) {
                ForEach(Array(QuickSearchPopupFilter.allCases.enumerated()), id: \.element.id) { index, filter in
                    SettingsToggleRow(
                        title: filter.displayName,
                        isOn: quickSearchFilterBinding(filter, coordinator: coordinator)
                    )
                    if index < QuickSearchPopupFilter.allCases.count - 1 {
                        SettingsInsetDivider()
                    }
                }
                SettingsInsetDivider()
                SettingsToggleRow(
                    title: "Show my categories",
                    isOn: Binding(
                        get: { QuickSearchFilterPreferences.showUserCategories },
                        set: {
                            QuickSearchFilterPreferences.showUserCategories = $0
                            coordinator.objectWillChange.send()
                        }
                    )
                )
                SettingsInsetDivider()
                SettingsActionButton(title: "Reset filters to defaults", systemImage: "arrow.counterclockwise") {
                    QuickSearchFilterPreferences.resetToDefaults()
                    coordinator.objectWillChange.send()
                }
            }
        }
        .onAppear {
            quickSearchListLimitText = "\(Preferences.quickSearchListLimit)"
        }
    }

    private func primaryDisplayID() -> CGDirectDisplayID {
        let id = (NSScreen.main?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        return CGDirectDisplayID(id)
    }

    private func commitQuickSearchListLimit() {
        let trimmed = quickSearchListLimitText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Int(trimmed) else {
            quickSearchListLimitText = "\(Preferences.quickSearchListLimit)"
            return
        }
        let clamped = Preferences.clampQuickSearchListLimit(parsed)
        if Preferences.quickSearchListLimit != clamped {
            Preferences.quickSearchListLimit = clamped
            coordinator.objectWillChange.send()
        }
        if quickSearchListLimitText != "\(clamped)" {
            quickSearchListLimitText = "\(clamped)"
        }
    }

    private func quickSearchFilterBinding(
        _ filter: QuickSearchPopupFilter,
        coordinator: AppCoordinator
    ) -> Binding<Bool> {
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

// MARK: - About

private struct AboutSettingsPanel: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    var body: some View {
        SettingsScrollContent {
            SettingsCard(title: "Quiet Clipboard", systemImage: "doc.on.clipboard.fill") {
                HStack(spacing: 14) {
                    AppBrandIcon(size: 52, cornerRadius: 12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version \(version) (\(build))")
                            .font(.headline)
                            .foregroundStyle(SettingsChrome.primaryText)
                        Text("Local clipboard history for Mac")
                            .font(.subheadline)
                            .foregroundStyle(SettingsChrome.secondaryText)
                    }
                }
            }

            SettingsCard(title: "Privacy", systemImage: "hand.raised") {
                SettingsCaption("Fully offline. No analytics, telemetry, or cloud accounts. The only optional network use is link preview fetching (toggle in Capture).")
            }

            SettingsCard(title: "License", systemImage: "doc.text") {
                SettingsCaption("MIT License — see repository for full text.")
            }
        }
    }
}
