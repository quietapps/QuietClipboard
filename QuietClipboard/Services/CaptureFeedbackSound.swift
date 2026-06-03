import AppKit

/// Plays system sounds when capture feedback is enabled (Settings → General).
@MainActor
enum CaptureFeedbackSound {
    static func playNewCapture() {
        guard Preferences.soundOnCopy else { return }
        NSSound(named: NSSound.Name("Pop"))?.play()
    }

    static func playSensitiveCapture() {
        guard Preferences.soundOnCopy else { return }
        NSSound(named: NSSound.Name("Basso"))?.play()
    }
}
