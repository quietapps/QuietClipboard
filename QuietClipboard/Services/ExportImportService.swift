import Foundation
import SwiftData
import AppKit

struct ExportedItem: Codable {
    var id: UUID
    var contentBase64: String
    var contentType: String
    var textContent: String?
    var ocrText: String?
    var title: String?
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var thumbnailBase64: String?
    var linkPreviewTitle: String?
    var linkPreviewDescription: String?
    var linkPreviewImageBase64: String?
    var colorHex: String?
    var fileSize: Int64?
    var fileMIMEType: String?
    var isFavorite: Bool
    var isSensitive: Bool
    var createdAt: Date
    var modifiedAt: Date
    var copyCount: Int?
    var firstCopiedAt: Date?
    var lastCopiedAt: Date?
    var contentHash: String?
}

struct ExportedCategory: Codable {
    var id: UUID
    var name: String
    var icon: String
    var color: String
    var sortOrder: Int
    var createdAt: Date
    var itemIDs: [UUID]
}

struct ExportPayload: Codable {
    var version: Int
    var exportedAt: Date
    var items: [ExportedItem]
    var categories: [ExportedCategory]
    /// Slot index (0–9) → item UUID string.
    var pinnedSlots: [String: String]?
}

@MainActor
enum ExportImportService {
    static func export(container: ModelContainer) throws -> URL {
        let context = ModelContext(container)
        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        let categories = try context.fetch(FetchDescriptor<Category>())

        let exportedItems = items.map { item in
            ExportedItem(
                id: item.id,
                contentBase64: item.content.base64EncodedString(),
                contentType: item.contentTypeRaw,
                textContent: item.textContent,
                ocrText: item.ocrText,
                title: item.title,
                sourceAppBundleID: item.sourceAppBundleID,
                sourceAppName: item.sourceAppName,
                thumbnailBase64: item.thumbnailData?.base64EncodedString(),
                linkPreviewTitle: item.linkPreviewTitle,
                linkPreviewDescription: item.linkPreviewDescription,
                linkPreviewImageBase64: item.linkPreviewImageData?.base64EncodedString(),
                colorHex: item.colorHex,
                fileSize: item.fileSize,
                fileMIMEType: item.fileMIMEType,
                isFavorite: item.isFavorite,
                isSensitive: item.isSensitive,
                createdAt: item.createdAt,
                modifiedAt: item.modifiedAt,
                copyCount: item.copyCount,
                firstCopiedAt: item.firstCopiedAt,
                lastCopiedAt: item.lastCopiedAt,
                contentHash: item.contentHash
            )
        }

        let exportedCats = categories.map { cat in
            ExportedCategory(
                id: cat.id,
                name: cat.name,
                icon: cat.icon,
                color: cat.color,
                sortOrder: cat.sortOrder,
                createdAt: cat.createdAt,
                itemIDs: cat.items.map(\.id)
            )
        }

        let pinnedRaw = PinnedClipStore.shared.slotItemIDs.reduce(into: [String: String]()) {
            $0[String($1.key)] = $1.value.uuidString
        }
        let payload = ExportPayload(version: 1, exportedAt: .now,
                                    items: exportedItems, categories: exportedCats,
                                    pinnedSlots: pinnedRaw.isEmpty ? nil : pinnedRaw)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuietClipboard-\(Int(Date.now.timeIntervalSince1970)).json")
        try data.write(to: url)
        return url
    }

    static func importFrom(_ url: URL, container: ModelContainer) throws -> Int {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(ExportPayload.self, from: data)

        let context = ModelContext(container)

        var catMap: [UUID: Category] = [:]
        for ec in payload.categories {
            let cat = Category(id: ec.id, name: ec.name, icon: ec.icon, color: ec.color,
                               sortOrder: ec.sortOrder, createdAt: ec.createdAt)
            context.insert(cat)
            catMap[ec.id] = cat
        }

        var imported = 0
        for ei in payload.items {
            let existing = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate { $0.id == ei.id }
            )
            if (try? context.fetch(existing).first) != nil { continue }
            guard let content = Data(base64Encoded: ei.contentBase64),
                  let type = ClipboardContentType(rawValue: ei.contentType) else { continue }
            let item = ClipboardItem(
                id: ei.id,
                content: content,
                contentType: type,
                textContent: ei.textContent,
                title: ei.title,
                sourceAppBundleID: ei.sourceAppBundleID,
                sourceAppName: ei.sourceAppName,
                thumbnailData: ei.thumbnailBase64.flatMap { Data(base64Encoded: $0) },
                colorHex: ei.colorHex,
                fileSize: ei.fileSize,
                fileMIMEType: ei.fileMIMEType,
                isFavorite: ei.isFavorite,
                isSensitive: ei.isSensitive,
                createdAt: ei.createdAt
            )
            item.ocrText = ei.ocrText
            item.linkPreviewTitle = ei.linkPreviewTitle
            item.linkPreviewDescription = ei.linkPreviewDescription
            item.linkPreviewImageData = ei.linkPreviewImageBase64.flatMap { Data(base64Encoded: $0) }
            item.modifiedAt = ei.modifiedAt
            item.contentHash = ei.contentHash ?? ""
            item.copyCount = ei.copyCount ?? 1
            item.firstCopiedAt = ei.firstCopiedAt ?? ei.createdAt
            item.lastCopiedAt = ei.lastCopiedAt ?? ei.createdAt
            context.insert(item)
            imported += 1
        }

        for ec in payload.categories {
            guard let cat = catMap[ec.id] else { continue }
            for iid in ec.itemIDs {
                let desc = FetchDescriptor<ClipboardItem>(
                    predicate: #Predicate { $0.id == iid }
                )
                if let item = try? context.fetch(desc).first {
                    item.categories.append(cat)
                }
            }
        }

        if let pinned = payload.pinnedSlots {
            var map: [Int: UUID] = [:]
            for (k, v) in pinned {
                guard let slot = Int(k), let id = UUID(uuidString: v) else { continue }
                map[slot] = id
            }
            for slot in 0..<PinnedClipStore.slotCount {
                if let id = map[slot] {
                    PinnedClipStore.shared.pin(itemID: id, to: slot)
                }
            }
            PinnedClipStore.shared.pruneMissingItems(context: context)
        }

        try context.save()
        return imported
    }

    static func presentSavePanel(_ source: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "QuietClipboard-export.json"
        panel.allowedContentTypes = [.json]
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: source, to: dest)
        }
    }

    static func presentOpenPanel(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            completion(response == .OK ? panel.url : nil)
        }
    }
}
