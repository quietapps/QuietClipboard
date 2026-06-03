import SwiftUI

struct ShortcutSettingsTab: View {
    @ObservedObject var settings: ShortcutSettings
    var onChange: () -> Void

    var body: some View {
        SettingsScrollContent {
            SettingsCard(
                title: "Global shortcuts",
                footer: "Click a shortcut field and press your key combination. Conflicts with system shortcuts are detected when recording."
            ) {
                HStack {
                    Spacer()
                    Button("Reset defaults") {
                        ShortcutManager.shared.resetDefaults()
                        onChange()
                    }
                    .controlSize(.small)
                    .foregroundStyle(SettingsChrome.accent)
                }
                .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                .padding(.top, 10)

                SettingsInsetDivider(leadingInset: SettingsChrome.rowHorizontalPadding)

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
        SettingsRowColumns(
            icon: shortcutIcon(for: action),
            iconTint: .indigo,
            controlWidth: SettingsChrome.controlColumnWidthWide
        ) {
            Text(action.displayName)
                .font(.subheadline.weight(.medium))
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

    private func shortcutIcon(for action: AppShortcutAction) -> String {
        switch action {
        case .openQuickSearch: return "magnifyingglass"
        case .openLibrary: return "books.vertical"
        case .toggleCapture: return "pause.circle"
        case .pasteClip0, .pasteClip1, .pasteClip2, .pasteClip3, .pasteClip4,
             .pasteClip5, .pasteClip6, .pasteClip7, .pasteClip8, .pasteClip9:
            return "number"
        case .pastePinned0, .pastePinned1, .pastePinned2, .pastePinned3, .pastePinned4,
             .pastePinned5, .pastePinned6, .pastePinned7, .pastePinned8, .pastePinned9:
            return "pin.fill"
        }
    }
}
