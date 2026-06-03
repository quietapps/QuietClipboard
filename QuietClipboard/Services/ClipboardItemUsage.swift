import AppKit
import SwiftData

@MainActor
enum ClipboardItemUsage {
    /// Writes item to the pasteboard and records usage so lists sort by most recently copied.
    static func copyToPasteboard(
        _ item: ClipboardItem,
        context: ModelContext,
        monitor: ClipboardMonitor? = nil
    ) {
        PasteboardHelper.write(item, to: .general)
        recordUsage(item, context: context, monitor: monitor)
    }

    /// Updates copy stats without writing the system pasteboard (auto-type delivery).
    static func recordUsage(
        _ item: ClipboardItem,
        context: ModelContext,
        monitor: ClipboardMonitor? = nil
    ) {
        let now = Date.now
        let frontApp = NSWorkspace.shared.frontmostApplication
        item.copyCount += 1
        item.lastCopiedAt = now
        item.modifiedAt = now

        let event = ClipboardCopyEvent(
            copiedAt: now,
            sourceAppBundleID: frontApp?.bundleIdentifier,
            sourceAppName: frontApp?.localizedName ?? "Quiet Clipboard"
        )
        event.item = item
        item.copyEvents.append(event)
        context.insert(event)

        try? context.save()
        monitor?.acknowledgeUserCopy(contentHash: item.contentHash)
    }
}
