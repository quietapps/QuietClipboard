import Foundation
import SwiftData
import AppKit

enum SharedStore {
    /// Directory holding the SwiftData store. Falls back to a temp dir if Application
    /// Support is somehow unavailable (sandbox edge cases, restricted volumes) so we
    /// never crash just resolving a path.
    static func storeDirectory() -> URL {
        let fm = FileManager.default
        let base: URL
        if let appSupport = try? fm.url(for: .applicationSupportDirectory,
                                        in: .userDomainMask,
                                        appropriateFor: nil,
                                        create: true) {
            base = appSupport
        } else {
            base = fm.temporaryDirectory
        }
        let dir = base.appendingPathComponent("QuietClipboard", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func storeURL() -> URL {
        storeDirectory().appendingPathComponent("QuietClipboard.sqlite")
    }

    /// Moves the existing SQLite store (plus its `-wal`/`-shm` siblings) into a timestamped
    /// `Recovered-…` folder so a fresh store can be created without destroying user data.
    /// Returns the human-readable backup path.
    @discardableResult
    static func quarantineStore() -> String {
        let fm = FileManager.default
        let dir = storeDirectory()
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupDir = dir.appendingPathComponent("Recovered-\(stamp)", isDirectory: true)
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let mainPath = storeURL().path
        for suffix in ["", "-wal", "-shm"] {
            let src = URL(fileURLWithPath: mainPath + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = backupDir.appendingPathComponent(src.lastPathComponent)
            try? fm.moveItem(at: src, to: dst)
        }
        return backupDir.path
    }
}

/// Builds the SwiftData container with graded recovery instead of crashing on failure:
/// 1. Normal on-disk store.
/// 2. If that fails (corruption / incompatible migration), quarantine the old store and
///    retry with a fresh one — data is preserved on disk, not lost.
/// 3. If even a fresh store fails, fall back to an in-memory store so the app still runs.
/// The optional `recoveryMessage` is surfaced to the user after launch.
enum StoreBootstrap {
    struct Result {
        let container: ModelContainer
        let recoveryMessage: String?
    }

    static func makeContainer(schema: Schema) -> Result {
        let config = ModelConfiguration(schema: schema, url: SharedStore.storeURL())

        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            return Result(container: container, recoveryMessage: nil)
        } catch {
            NSLog("QuietClipboard: store open failed (\(error)). Quarantining and retrying.")
        }

        let backupPath = SharedStore.quarantineStore()
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            return Result(
                container: container,
                recoveryMessage: "Quiet Clipboard couldn’t open your clipboard database, so it started a new one. Your previous data was moved to:\n\n\(backupPath)"
            )
        } catch {
            NSLog("QuietClipboard: fresh store failed (\(error)). Falling back to in-memory.")
        }

        do {
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [memConfig])
            return Result(
                container: container,
                recoveryMessage: "Quiet Clipboard couldn’t open or rebuild its database, so it’s running in temporary memory. Clips saved this session won’t persist — please restart the app to try again."
            )
        } catch {
            // In-memory creation failing means the schema itself is invalid — a build-time
            // programming error, not a runtime/user condition. Crash loudly here only.
            fatalError("QuietClipboard: unable to create any ModelContainer: \(error)")
        }
    }

    @MainActor
    static func presentRecoveryAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Clipboard Database Recovered"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
