import SwiftUI
import AppKit

/// Opens the app `Settings` scene. Uses `SettingsLink` when available; otherwise the action captured from the menu bar scene.
struct AppSettingsLink<Label: View>: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ViewBuilder private let label: () -> Label

    init(@ViewBuilder label: @escaping () -> Label) {
        self.label = label
    }

    var body: some View {
        Group {
            if let openSettings = coordinator.openSettings {
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                } label: {
                    label()
                }
            } else {
                SettingsLink(label: label)
            }
        }
    }
}
