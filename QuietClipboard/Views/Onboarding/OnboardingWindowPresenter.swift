import AppKit
import SwiftUI

/// Centered welcome window — first launch and menu bar "Welcome Tour".
@MainActor
final class OnboardingWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = OnboardingWindowPresenter()

    private var window: NSWindow?
    private weak var hostingController: NSHostingController<AnyView>?
    private var didCompleteThisSession = false

    func present(coordinator: AppCoordinator, force: Bool = false) {
        guard force || !Preferences.hasCompletedOnboarding else { return }
        didCompleteThisSession = false

        if let window, let host = hostingController {
            host.rootView = AnyView(root(coordinator: coordinator))
            show(window)
            return
        }

        let host = NSHostingController(rootView: AnyView(root(coordinator: coordinator)))
        hostingController = host
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.title = "Welcome to Quiet Clipboard"
        w.identifier = NSUserInterfaceItemIdentifier("onboarding")
        w.contentViewController = host
        w.delegate = self
        w.isReleasedWhenClosed = false
        w.backgroundColor = .black
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.center()

        window = w
        show(w)
    }

    private func root(coordinator: AppCoordinator) -> some View {
        OnboardingView(
            onComplete: { [weak self] in
                self?.markCompletedAndClose()
            },
            onOpenCaptureSettings: {
                coordinator.openSettings(panel: .capture)
            },
            onTryQuickSearch: {
                coordinator.toggleQuickSearchForOnboarding()
            },
            onOpenLibrary: {
                coordinator.openLibraryWindow()
            }
        )
        .environmentObject(coordinator)
    }

    private func markCompletedAndClose() {
        didCompleteThisSession = true
        Preferences.hasCompletedOnboarding = true
        window?.close()
    }

    private func show(_ window: NSWindow) {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        if !didCompleteThisSession {
            // User closed with ✕ — show again on next launch until they finish or skip.
        }
        (notification.object as? NSWindow)?.orderOut(nil)
    }
}
