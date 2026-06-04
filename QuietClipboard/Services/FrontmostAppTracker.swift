import AppKit

/// Remembers the most recently active app that ISN'T Quiet Clipboard, so paste actions triggered
/// while one of our own windows (Library, Settings) is frontmost still target the user's real app
/// instead of pasting into ourselves.
@MainActor
final class FrontmostAppTracker {
    static let shared = FrontmostAppTracker()

    private(set) var lastExternalApp: NSRunningApplication?
    private var observer: NSObjectProtocol?
    private let selfBundleID = Bundle.main.bundleIdentifier

    func start() {
        guard observer == nil else { return }
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != selfBundleID {
            lastExternalApp = front
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != self.selfBundleID else { return }
            MainActor.assumeIsolated { self.lastExternalApp = app }
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
