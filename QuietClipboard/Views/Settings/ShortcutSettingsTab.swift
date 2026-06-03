import SwiftUI

struct ShortcutSettingsTab: View {
    @ObservedObject var settings: ShortcutSettings
    var onChange: () -> Void

    var body: some View {
        SettingsScrollContent {
            SettingsCard(
                title: "Global shortcuts",
                systemImage: "command",
                footer: "Click a shortcut field and press your key combination. Conflicts with system shortcuts are detected when recording."
            ) {
                HStack {
                    Spacer()
                    Button("Reset defaults") {
                        ShortcutManager.shared.resetDefaults()
                        onChange()
                    }
                    .controlSize(.small)
                }

                SettingsInsetDivider()

                ForEach(Array(AppShortcutAction.allCases.enumerated()), id: \.element.id) { index, action in
                    shortcutRow(for: action)
                    if index < AppShortcutAction.allCases.count - 1 {
                        SettingsInsetDivider()
                    }
                }
            }
        }
    }

    private func shortcutRow(for action: AppShortcutAction) -> some View {
        SettingsRowColumns(controlWidth: SettingsChrome.controlColumnWidthWide) {
            Text(action.displayName)
                .font(.body)
                .foregroundStyle(SettingsChrome.primaryText)
        } control: {
            ShortcutRecorderView(combo: Binding(
                get: { settings.bindings[action] },
                set: { newValue in
                    ShortcutManager.shared.updateBinding(newValue, for: action)
                    onChange()
                }
            ))
        }
        .padding(.vertical, SettingsChrome.rowVerticalPadding)
    }
}
