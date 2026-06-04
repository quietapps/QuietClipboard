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
                        .environmentObject(coordinator)
                }
            }
        }
        .frame(width: SettingsChrome.windowWidth)
        .frame(idealHeight: SettingsChrome.windowIdealHeight)
        .frame(minHeight: SettingsChrome.windowMinHeight)
        .fixedSize(horizontal: true, vertical: false)
        .background(SettingsChrome.shellBackground)
        .background(SettingsWindowConfigurator())
        .onAppear { applyPendingSettingsPanel() }
        .onChange(of: coordinator.pendingSettingsPanel) { _, _ in
            applyPendingSettingsPanel()
        }
    }

    private func applyPendingSettingsPanel() {
        guard let target = coordinator.pendingSettingsPanel else { return }
        panel = target
        coordinator.pendingSettingsPanel = nil
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
        window.title = "Quiet Clipboard"
        window.backgroundColor = .black
        window.isOpaque = true
        let width = SettingsChrome.windowWidth
        let minHeight = SettingsChrome.windowMinHeight
        let idealHeight = SettingsChrome.windowIdealHeight
        window.minSize = NSSize(width: width, height: minHeight)
        window.maxSize = NSSize(width: width, height: 16_000)
        var frame = window.frame
        var needsResize = false
        if abs(frame.width - width) > 2 {
            frame.size.width = width
            needsResize = true
        }
        if frame.height < idealHeight - 2 {
            frame.size.height = idealHeight
            needsResize = true
        }
        if needsResize {
            window.setFrame(frame, display: true)
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
                footer: "Sound plays when a new clip is saved; a lower tone plays for sensitive captures."
            ) {
                SettingsToggleRow(
                    title: "Launch at login",
                    icon: "power",
                    iconTint: .green,
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
                    icon: "pause.circle.fill",
                    iconTint: .orange,
                    isOn: Binding(
                        get: { monitor.isPaused },
                        set: { monitor.setPaused($0) }
                    )
                )
                SettingsInsetDivider()
                SettingsToggleRow(
                    title: "Sound on capture",
                    icon: "speaker.wave.2.fill",
                    iconTint: .red,
                    isOn: Binding(
                        get: { Preferences.soundOnCopy },
                        set: { Preferences.soundOnCopy = $0 }
                    )
                )
            }

            SettingsCard(
                title: "Paste",
                footer: "Auto-paste requires Accessibility permission. When off, picking a clip only copies it; press ⌘V to paste manually."
            ) {
                SettingsToggleRow(
                    title: "Auto-paste into active app",
                    subtitle: "After choosing a clip, also paste it into the previously-active app",
                    icon: "wand.and.stars",
                    iconTint: .indigo,
                    isOn: Binding(
                        get: { Preferences.autoPasteEnabled },
                        set: { Preferences.autoPasteEnabled = $0 }
                    )
                )
                SettingsInsetDivider()
                SettingsPickerRow(
                    title: "Default paste method",
                    icon: "arrow.right.doc.on.clipboard",
                    iconTint: .blue,
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
                SettingsInsetDivider()
                SettingsToggleRow(
                    title: "Keep clipboard after paste",
                    subtitle: "Restores your previous clipboard once the clip is pasted",
                    icon: "arrow.uturn.backward",
                    iconTint: .teal,
                    isOn: Binding(
                        get: { Preferences.restoreClipboardAfterPaste },
                        set: { Preferences.restoreClipboardAfterPaste = $0 }
                    )
                )
                SettingsInsetDivider()
                SettingsToggleRow(
                    title: "Show paste confirmation",
                    subtitle: "Brief on-screen confirmation after copy and paste",
                    icon: "checkmark.bubble.fill",
                    iconTint: .green,
                    isOn: Binding(
                        get: { Preferences.showPasteFeedbackHUD },
                        set: { Preferences.showPasteFeedbackHUD = $0 }
                    )
                )
            }

            SettingsCard(title: "Appearance") {
                SettingsPickerRow(
                    title: "List previews",
                    icon: "paintbrush.fill",
                    iconTint: .purple,
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
                if let style = ClipPreviewStyle.allCases.first(where: { $0 == Preferences.clipPreviewStyle }) {
                    Text(style.detail)
                        .font(.caption)
                        .foregroundStyle(SettingsChrome.secondaryText)
                        .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                        .padding(.bottom, 10)
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
                footer: "Maximum clips shown when browsing or searching in Quick Search. Default \(Preferences.quickSearchListLimitDefault), up to \(Preferences.quickSearchListLimitMax). Older clips stay in the Library."
            ) {
                SettingsLabeledFieldRow(title: "Clips in list", icon: "list.number", iconTint: .blue) {
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
                    icon: "arrow.up.left.and.arrow.down.right",
                    iconTint: .teal,
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

                if Preferences.quickSearchPlacement == .screenCenterChosen {
                    SettingsInsetDivider()
                    SettingsPickerRow(
                        title: "Display",
                        icon: "display",
                        iconTint: .gray,
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

                SettingsInsetDivider()

                SettingsToggleRow(
                    title: "Show preview",
                    icon: "sidebar.right",
                    iconTint: .indigo,
                    isOn: Binding(
                        get: { Preferences.quickSearchPreviewEnabled },
                        set: {
                            Preferences.quickSearchPreviewEnabled = $0
                            coordinator.objectWillChange.send()
                        }
                    )
                )

                SettingsInsetDivider()

                HStack {
                    SettingsActionButton(title: "Reset popup size", systemImage: "arrow.counterclockwise") {
                        coordinator.resetQuickSearchSize()
                    }
                }
                .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                .padding(.vertical, 10)

            }

            SettingsCard(
                title: "Filter bar",
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
                    icon: "folder.fill",
                    iconTint: .orange,
                    isOn: Binding(
                        get: { QuickSearchFilterPreferences.showUserCategories },
                        set: {
                            QuickSearchFilterPreferences.showUserCategories = $0
                            coordinator.objectWillChange.send()
                        }
                    )
                )
                SettingsInsetDivider()
                HStack {
                    SettingsActionButton(title: "Reset filters to defaults", systemImage: "arrow.counterclockwise") {
                        QuickSearchFilterPreferences.resetToDefaults()
                        coordinator.objectWillChange.send()
                    }
                }
                .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                .padding(.vertical, 10)
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
    @EnvironmentObject private var coordinator: AppCoordinator

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    var body: some View {
        SettingsScrollContent {
            SettingsCard(title: "About") {
                HStack(spacing: 14) {
                    AppBrandIcon(size: 52, cornerRadius: 12)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quiet Clipboard")
                            .font(.headline)
                            .foregroundStyle(SettingsChrome.primaryText)
                        Text("Version \(version) (\(build))")
                            .font(.subheadline)
                            .foregroundStyle(SettingsChrome.secondaryText)
                        Text("Local clipboard history for Mac")
                            .font(.caption)
                            .foregroundStyle(SettingsChrome.tertiaryText)
                    }
                }
                .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                .padding(.vertical, 14)
            }

            SettingsCard(title: "Privacy") {
                Text("Fully offline. No analytics, telemetry, or cloud accounts. The only optional network use is link preview fetching (toggle in Capture).")
                    .font(.caption)
                    .foregroundStyle(SettingsChrome.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                    .padding(.vertical, 12)
            }

            SettingsCard(title: "License") {
                Text("MIT License — see repository for full text.")
                    .font(.caption)
                    .foregroundStyle(SettingsChrome.secondaryText)
                    .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                    .padding(.vertical, 12)
            }

            SettingsCard(title: "Help") {
                Button("Show Welcome Tour…") {
                    coordinator.presentOnboarding(force: true)
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SettingsChrome.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                .padding(.vertical, 12)
            }
        }
    }
}
