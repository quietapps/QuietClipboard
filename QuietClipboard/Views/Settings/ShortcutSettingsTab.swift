import SwiftUI

struct ShortcutSettingsTab: View {
    @ObservedObject var settings: ShortcutSettings
    var onChange: () -> Void

    var body: some View {
        Form {
            Section {
                ForEach(AppShortcutAction.allCases) { action in
                    row(for: action)
                }
            } header: {
                HStack {
                    Text("Global Shortcuts")
                    Spacer()
                    Button("Reset Defaults") {
                        ShortcutManager.shared.resetDefaults()
                        onChange()
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func row(for action: AppShortcutAction) -> some View {
        HStack {
            Text(action.displayName)
            Spacer()
            ShortcutRecorderView(combo: Binding(
                get: { settings.bindings[action] },
                set: { newValue in
                    ShortcutManager.shared.updateBinding(newValue, for: action)
                    onChange()
                }
            ))
        }
    }
}
