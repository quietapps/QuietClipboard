import SwiftUI

struct CaptureSettingsTab: View {
    @EnvironmentObject var monitor: ClipboardMonitor
    @State private var sensitiveEnabled: Bool = Preferences.sensitiveDetectionEnabled
    @State private var sensitiveBehavior: SensitiveBehavior = Preferences.sensitiveBehavior
    @State private var capturedTypes: Set<ClipboardContentType> = Preferences.capturedTypes
    @State private var linkPreviewsEnabled: Bool = Preferences.linkPreviewsEnabled

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
