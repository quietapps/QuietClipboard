import SwiftUI

/// Captures `openSettings` from the menu bar scene so hosted windows (Library) can use `SettingsLink`.
struct OpenSettingsCapture: View {
    @Environment(\.openSettings) private var openSettings
    let coordinator: AppCoordinator

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                coordinator.setOpenSettings(openSettings)
            }
    }
}
