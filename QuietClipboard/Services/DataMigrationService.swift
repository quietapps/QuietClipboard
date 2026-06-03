import Foundation
import SwiftData

enum DataMigrationService {
    private static let migrationKey = "QC.CopyTrackingMigrated.v1"
    private static let structuredDataKey = "QC.StructuredDataMigrated.v1"

    @MainActor
    static func migrateIfNeeded(container: ModelContainer) {
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
