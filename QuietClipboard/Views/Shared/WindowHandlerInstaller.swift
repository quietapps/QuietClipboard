import SwiftUI

/// Registers `openWindow` with the app coordinator (menu bar scene provides the environment).
struct WindowHandlerInstaller: View {
    @Environment(\.openWindow) private var openWindow
    let coordinator: AppCoordinator

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                coordinator.setOpenWindowHandler { id in
                    if id == "library" {
                        LibraryWindowPresenter.shared.present(coordinator: coordinator)
                    } else {
                        openWindow(id: id)
                    }
                }
            }
    }
}
