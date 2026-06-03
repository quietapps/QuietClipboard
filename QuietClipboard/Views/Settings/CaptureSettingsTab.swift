import SwiftUI

struct CaptureSettingsTab: View {
    @EnvironmentObject var monitor: ClipboardMonitor
    @State private var sensitiveEnabled: Bool = Preferences.sensitiveDetectionEnabled
    @State private var sensitiveBehavior: SensitiveBehavior = Preferences.sensitiveBehavior
    @State private var capturedTypes: Set<ClipboardContentType> = Preferences.capturedTypes
    @State private var linkPreviewsEnabled: Bool = Preferences.linkPreviewsEnabled
    @State private var autoCategorize: Bool = Preferences.autoCategorizationEnabled
    @State private var autoCategorizeML: Bool = Preferences.autoCategorizationML
    @State private var collapseDuplicates: Bool = Preferences.collapseDuplicates
    @State private var captureUniversalClipboard: Bool = Preferences.captureUniversalClipboard

    var body: some View {
        Form {
            Section("Capture") {
                Toggle("Pause capture", isOn: Binding(
                    get: { monitor.isPaused },
                    set: { monitor.setPaused($0) }
                ))
            }

            Section("Content Types") {
                ForEach(ClipboardContentType.allCases) { t in
                    Toggle(isOn: Binding(
                        get: { capturedTypes.contains(t) },
                        set: { on in
                            if on { capturedTypes.insert(t) } else { capturedTypes.remove(t) }
                            Preferences.capturedTypes = capturedTypes
                        }
                    )) {
                        Label(t.displayName, systemImage: t.systemImage)
                    }
                }
            }

            Section("Sensitive Content") {
                Toggle("Detect sensitive content", isOn: $sensitiveEnabled)
                    .onChange(of: sensitiveEnabled) { _, v in
                        Preferences.sensitiveDetectionEnabled = v
                    }
                Picker("When detected", selection: $sensitiveBehavior) {
                    ForEach(SensitiveBehavior.allCases) { b in
                        Text(b.displayName).tag(b)
                    }
                }
                .onChange(of: sensitiveBehavior) { _, v in
                    Preferences.sensitiveBehavior = v
                }
                .disabled(!sensitiveEnabled)
                if sensitiveEnabled, sensitiveBehavior == .saveHidden {
                    Text("Saved clips stay blurred in the library, Quick Search, and menu bar until you tap Reveal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Organization") {
                Toggle("Suggest categories", isOn: $autoCategorize)
                    .onChange(of: autoCategorize) { _, v in Preferences.autoCategorizationEnabled = v }
                Toggle("Use on-device language analysis", isOn: $autoCategorizeML)
                    .onChange(of: autoCategorizeML) { _, v in Preferences.autoCategorizationML = v }
                    .disabled(!autoCategorize)
                Toggle("Collapse near-duplicate clips", isOn: $collapseDuplicates)
                    .onChange(of: collapseDuplicates) { _, v in Preferences.collapseDuplicates = v }
            }

            Section("Universal Clipboard") {
                Toggle("Save copies from iPhone and iPad", isOn: $captureUniversalClipboard)
                    .onChange(of: captureUniversalClipboard) { _, v in
                        Preferences.captureUniversalClipboard = v
                    }
                Text("Detects Handoff via com.apple.is-remote-clipboard and tags clips as iPhone, iPad, or iPhone/iPad.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Links") {
                Toggle("Fetch link previews", isOn: $linkPreviewsEnabled)
                    .onChange(of: linkPreviewsEnabled) { _, v in
                        Preferences.linkPreviewsEnabled = v
                    }
                Text("Only network request the app makes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
