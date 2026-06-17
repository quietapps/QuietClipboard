import Foundation
import SwiftData

enum DataMigrationService {
    private static let migrationKey = "QC.CopyTrackingMigrated.v1"
    private static let structuredDataKey = "QC.StructuredDataMigrated.v1"
    private static let externalStorageKey = "QC.ExternalStorageMigrated.v1"

    @MainActor
    static func migrateIfNeeded(container: ModelContainer) {
        migrateExternalStorageIfNeeded(container: container)
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }
        let context = ModelContext(container)
        guard let items = try? context.fetch(FetchDescriptor<ClipboardItem>()) else { return }

        for item in items {
            if item.firstCopiedAt == nil {
                item.firstCopiedAt = item.createdAt
            }
            if item.lastCopiedAt == nil {
                item.lastCopiedAt = item.createdAt
            }
            if item.copyCount < 1 {
                item.copyCount = 1
            }
            if item.copyEvents.isEmpty {
                let event = ClipboardCopyEvent(
                    copiedAt: item.effectiveFirstCopiedAt,
                    sourceAppBundleID: item.sourceAppBundleID,
                    sourceAppName: item.sourceAppName
                )
                event.item = item
                item.copyEvents.append(event)
                context.insert(event)
            }
            if item.normalizedFingerprint.isEmpty {
                item.normalizedFingerprint = DuplicateDetectionService.normalizedFingerprint(
                    text: item.textContent,
                    contentType: item.contentType,
                    contentHash: item.contentHash
                )
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: migrationKey)
        migrateStructuredDataIfNeeded(container: container)
    }

    /// `content` became `@Attribute(.externalStorage)`, but the SwiftData schema migration leaves
    /// pre-existing blobs inline in the SQLite row — so they're still faulted into memory on every
    /// fetch. Force a one-time rewrite of each item's `content`; on save Core Data re-evaluates
    /// external storage and moves the large payloads out to `_EXTERNAL_DATA`. Saves in batches so
    /// a large history doesn't build one giant transaction. Small blobs (most text) stay inline,
    /// which is fine — they're cheap.
    @MainActor
    private static func migrateExternalStorageIfNeeded(container: ModelContainer) {
        guard !UserDefaults.standard.bool(forKey: externalStorageKey) else { return }
        let context = ModelContext(container)
        guard let items = try? context.fetch(FetchDescriptor<ClipboardItem>()) else { return }

        // Byte-equal reassignment is elided by the change-tracker, so force a genuine change and
        // then restore the exact bytes. Each item is mutated and restored before the next, with a
        // save after every step, so at most one item is ever in the temporary state — an
        // interruption can't leave the history corrupt.
        for item in items {
            let original = item.content
            guard original.count >= 4096 else { continue } // tiny blobs stay inline anyway
            item.content = original + Data([0])             // length changes → real dirty write
            try? context.save()
            item.content = original                          // restore exact bytes; relocates to external if large
            try? context.save()
        }
        UserDefaults.standard.set(true, forKey: externalStorageKey)
    }

    @MainActor
    private static func migrateStructuredDataIfNeeded(container: ModelContainer) {
        guard !UserDefaults.standard.bool(forKey: structuredDataKey) else { return }
        let context = ModelContext(container)
        guard let items = try? context.fetch(FetchDescriptor<ClipboardItem>()) else { return }
        for item in items where item.structuredDataJSON == nil {
            item.applyStructuredDataDetection()
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: structuredDataKey)
    }
}
