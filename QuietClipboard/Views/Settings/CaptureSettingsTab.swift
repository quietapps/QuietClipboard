import SwiftUI

struct CaptureSettingsTab: View {
    @EnvironmentObject var monitor: ClipboardMonitor
    @State private var sensitiveEnabled: Bool = Preferences.sensitiveDetectionEnabled
    @State private var sensitiveBehavior: SensitiveBehavior = Preferences.sensitiveBehavior
    @State private var enabledCaptureGroups: Set<CaptureContentGroup> = Preferences.enabledCaptureGroups
    @State private var capturedTypes: Set<ClipboardContentType> = Preferences.capturedTypes
    @State private var linkPreviewsEnabled: Bool = Preferences.linkPreviewsEnabled
    @State private var autoCategorize: Bool = Preferences.autoCategorizationEnabled
    @State private var autoCategorizeML: Bool = Preferences.autoCategorizationML
    @State private var collapseDuplicates: Bool = Preferences.collapseDuplicates
    @State private var captureUniversalClipboard: Bool = Preferences.captureUniversalClipboard

    var body: some View {
        SettingsScrollContent {
            SettingsCard(title: "Capture", systemImage: "doc.on.clipboard") {
                SettingsToggleRow(
                    title: "Pause capture",
                    isOn: Binding(
                        get: { monitor.isPaused },
                        set: { monitor.setPaused($0) }
                    )
                )
            }

            SettingsCard(
                title: "Excluded apps",
                systemImage: "app.badge.checkmark",
                footer: "Copies made while one of these apps is frontmost are ignored. A few sensitive apps are excluded by default; add more from Recommended."
            ) {
                ExcludedAppsSettingsView()
            }

            SettingsCard(
                title: "Content types",
                systemImage: "square.grid.2x2",
                footer: "Turn off a group to stop capturing all of its types. With a group on, disable individual types you do not want saved."
            ) {
                CaptureContentTypeSettings(
                    enabledGroups: $enabledCaptureGroups,
                    capturedTypes: $capturedTypes
                )
            }

            SettingsCard(title: "Sensitive content", systemImage: "lock.shield") {
                SettingsToggleRow(
                    title: "Detect sensitive content",
                    isOn: $sensitiveEnabled
                )
                .onChange(of: sensitiveEnabled) { _, v in
                    Preferences.sensitiveDetectionEnabled = v
                }

                SettingsInsetDivider()

                SettingsPickerRow(
                    title: "When detected",
                    disabled: !sensitiveEnabled,
                    selection: $sensitiveBehavior
                ) {
                    ForEach(SensitiveBehavior.allCases) { b in
                        Text(b.displayName).tag(b)
                    }
                }
                .onChange(of: sensitiveBehavior) { _, v in
                    Preferences.sensitiveBehavior = v
                }

                if sensitiveEnabled, sensitiveBehavior == .saveHidden {
                    SettingsCaption("Saved clips stay blurred in the library, Quick Search, and menu bar until you tap Reveal.")
                        .padding(.top, 4)
                }
            }

            SettingsCard(title: "Organization", systemImage: "folder") {
                SettingsToggleRow(title: "Suggest categories", isOn: $autoCategorize)
                    .onChange(of: autoCategorize) { _, v in Preferences.autoCategorizationEnabled = v }
                SettingsInsetDivider()
                SettingsToggleRow(
                    title: "Use on-device language analysis",
                    isOn: $autoCategorizeML
                )
                .disabled(!autoCategorize)
                .onChange(of: autoCategorizeML) { _, v in Preferences.autoCategorizationML = v }
                SettingsInsetDivider()
                SettingsToggleRow(title: "Collapse near-duplicate clips", isOn: $collapseDuplicates)
                    .onChange(of: collapseDuplicates) { _, v in Preferences.collapseDuplicates = v }
            }

            SettingsCard(
                title: "Universal Clipboard",
                systemImage: "iphone.and.arrow.forward",
                footer: "Detects Handoff via com.apple.is-remote-clipboard and tags clips as iPhone, iPad, or iPhone/iPad."
            ) {
                SettingsToggleRow(
                    title: "Save copies from iPhone and iPad",
                    isOn: $captureUniversalClipboard
                )
                .onChange(of: captureUniversalClipboard) { _, v in
                    Preferences.captureUniversalClipboard = v
                }
            }

            SettingsCard(
                title: "Links",
                systemImage: "link",
                footer: "Only network request the app makes."
            ) {
                SettingsToggleRow(title: "Fetch link previews", isOn: $linkPreviewsEnabled)
                    .onChange(of: linkPreviewsEnabled) { _, v in
                        Preferences.linkPreviewsEnabled = v
                    }
            }
        }
    }
}
