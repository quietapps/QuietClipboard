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
        monitor?.acknowledgeOwnPasteboardWrite()
        recordUsage(item, context: context, monitor: monitor)
    }

    /// Writes only the plain-text representation (strips rich formatting) and records usage.
    static func copyPlainTextToPasteboard(
        _ item: ClipboardItem,
        context: ModelContext,
        monitor: ClipboardMonitor? = nil
    ) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let text = item.resolvedText {
            pb.setString(text, forType: .string)
        } else {
            PasteboardHelper.write(item, to: pb)   // non-text clip: fall back to normal write
        }
        monitor?.acknowledgeOwnPasteboardWrite()
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

        // Items fetched via a SwiftUI `@Query` live in the view's environment context. Inserting a
        // related model into a *different* ad-hoc context throws SwiftData's "Illegal attempt to
        // insert a model in to a different model context" — which can crash on save. Always
        // insert events into the item's own context when it has one.
        let targetContext = item.modelContext ?? context

        let event = ClipboardCopyEvent(
            copiedAt: now,
            sourceAppBundleID: frontApp?.bundleIdentifier,
            sourceAppName: frontApp?.localizedName ?? "Quiet Clipboard"
        )
        // Insert BEFORE assigning the relationship. Setting `event.item = item` first causes
        // SwiftData to auto-insert the event into `item.modelContext` via the inverse, which can
        // collide with a later explicit insert and trap with "Illegal attempt to insert a model
        // in to a different model context".
        targetContext.insert(event)
        event.item = item
        item.copyEvents.append(event)

        try? targetContext.save()
        _ = monitor
    }
}
