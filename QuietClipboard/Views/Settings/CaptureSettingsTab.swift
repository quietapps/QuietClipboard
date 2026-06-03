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
            SettingsCard(title: "Capture") {
                SettingsToggleRow(
                    title: "Pause capture",
                    icon: "pause.circle.fill",
                    iconTint: .orange,
                    isOn: Binding(
                        get: { monitor.isPaused },
                        set: { monitor.setPaused($0) }
                    )
                )
            }

            SettingsCard(
                title: "Excluded apps",
                footer: "Copies made while one of these apps is frontmost are ignored. A few sensitive apps are excluded by default; add more from Recommended."
            ) {
                ExcludedAppsSettingsView()
            }

            SettingsCard(
                title: "Content types",
                footer: "Turn off a group to stop capturing all of its types. With a group on, disable individual types you do not want saved."
            ) {
                CaptureContentTypeSettings(
                    enabledGroups: $enabledCaptureGroups,
                    capturedTypes: $capturedTypes
                )
            }

            SettingsCard(title: "Sensitive content") {
                SettingsToggleRow(
                    title: "Detect sensitive content",
                    subtitle: "Passwords, API keys, tokens, and similar",
                    icon: "lock.shield.fill",
                    iconTint: .red,
                    isOn: $sensitiveEnabled
                )
                .onChange(of: sensitiveEnabled) { _, v in
                    Preferences.sensitiveDetectionEnabled = v
                }

                SettingsInsetDivider()

                SettingsPickerRow(
                    title: "When detected",
                    icon: "eye.slash.fill",
                    iconTint: .orange,
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
                    Text("Saved clips stay blurred in the library, Quick Search, and menu bar until you tap Reveal.")
                        .font(.caption)
                        .foregroundStyle(SettingsChrome.secondaryText)
                        .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                        .padding(.bottom, 10)
                }
            }

            SettingsCard(title: "Organization") {
                SettingsToggleRow(
                    title: "Suggest categories",
                    icon: "folder.fill",
                    iconTint: .orange,
                    isOn: $autoCategorize
                )
                .onChange(of: autoCategorize) { _, v in Preferences.autoCategorizationEnabled = v }
                SettingsInsetDivider()
                SettingsToggleRow(
                    title: "Use on-device language analysis",
                    icon: "brain.head.profile",
                    iconTint: .purple,
                    isOn: $autoCategorizeML
                )
                .disabled(!autoCategorize)
                .onChange(of: autoCategorizeML) { _, v in Preferences.autoCategorizationML = v }
                SettingsInsetDivider()
                SettingsToggleRow(
                    title: "Collapse near-duplicate clips",
                    icon: "square.stack.3d.down.right",
                    iconTint: .teal,
                    isOn: $collapseDuplicates
                )
                .onChange(of: collapseDuplicates) { _, v in Preferences.collapseDuplicates = v }
            }

            SettingsCard(
                title: "Universal Clipboard",
                footer: "Detects Handoff via com.apple.is-remote-clipboard and tags clips as iPhone, iPad, or iPhone/iPad."
            ) {
                SettingsToggleRow(
                    title: "Save copies from iPhone and iPad",
                    icon: "iphone.and.arrow.forward",
                    iconTint: .blue,
                    isOn: $captureUniversalClipboard
                )
                .onChange(of: captureUniversalClipboard) { _, v in
                    Preferences.captureUniversalClipboard = v
                }
            }

            SettingsCard(
                title: "Links",
                footer: "Only network request the app makes."
            ) {
                SettingsToggleRow(
                    title: "Fetch link previews",
                    icon: "link",
                    iconTint: .blue,
                    isOn: $linkPreviewsEnabled
                )
                .onChange(of: linkPreviewsEnabled) { _, v in
                    Preferences.linkPreviewsEnabled = v
                }
            }
        }
    }
}
