import Foundation
import SwiftData
import AppKit
import UniformTypeIdentifiers
import Compression

/// Container magic for compressed backups: 5 ASCII bytes followed by zlib-deflated JSON.
/// Legacy exports are bare JSON with no prefix — import sniffs this so old `.json`
/// backups keep working.
private let backupMagic = Data("QCBK1".utf8)

extension UTType {
    /// Declared in Info.plist under `UTExportedTypeDeclarations` (and mirrored in
    /// project.yml, which regenerates the plist). Conforms to `public.data`.
    static let quietClipboardBackup = UTType(
        exportedAs: "app.quiet.QuietClipboard.backup",
        conformingTo: .data
    )
}

enum ExportImportError: LocalizedError {
    case unsupportedVersion(Int)
    case corruptArchive
    case importCancelled
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v):
            return "This backup was created by a newer version of Quiet Clipboard (format \(v)). Update the app to import it."
        case .corruptArchive:
            return "The backup file is damaged or incomplete."
        case .importCancelled:
            return "Import was canceled."
        case .fileTooLarge:
            return "The backup file is too large to import."
        }
    }
}

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
    /// Bump only on JSON schema changes — the QCBK1 compression wrapper is
    /// transport-level and does not affect this number.
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    /// Written on export so import can detect truncated files. Absent in legacy
    /// backups, in which case the integrity check is skipped.
    var itemCount: Int?
    var items: [ExportedItem]
    var categories: [ExportedCategory]
    /// Slot index (0–9) → item UUID string.
    var pinnedSlots: [String: String]?
}

@MainActor
enum ExportImportService {
    struct ExportResult {
        var url: URL
        var itemCount: Int
    }

    static func export(container: ModelContainer) async throws -> ExportResult {
        let payload = try buildPayload(container: container)
        let count = payload.items.count
        FeedbackHUD.shared.show("Exporting \(clips(count))…",
                                systemImage: "square.and.arrow.up",
                                duration: 2.0)
        // Encode + deflate can take seconds for image-heavy histories; keep it off
        // the main thread. Only the SwiftData reads above need main.
        let url = try await Task.detached(priority: .userInitiated) {
            try writeBackup(payload)
        }.value
        return ExportResult(url: url, itemCount: count)
    }

    static func importFrom(_ url: URL, container: ModelContainer) async throws -> Int {
        // Inflate + decode off main for the same reason as export; alerts and the
        // ModelContext writes below stay on main.
        let payload: ExportPayload
        do {
            payload = try await Task.detached(priority: .userInitiated) {
                try decodePayload(contentsOf: url)
            }.value
        } catch {
            FeedbackHUD.shared.show("Import failed",
                                    systemImage: "exclamationmark.triangle.fill",
                                    isWarning: true, duration: 2.0)
            throw error
        }

        guard payload.version <= ExportPayload.currentVersion else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Can't Import This Backup"
            alert.informativeText = "This backup was created by a newer version of Quiet Clipboard (format \(payload.version); this version reads up to \(ExportPayload.currentVersion)). Update the app and try again."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            throw ExportImportError.unsupportedVersion(payload.version)
        }

        // A mismatch means the file was truncated or edited after export. Let the
        // user decide — partial restores are still useful.
        if let expected = payload.itemCount, expected != payload.items.count {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Backup May Be Incomplete"
            alert.informativeText = "The backup reports \(clips(expected)) but \(clips(payload.items.count)) could be read — the file may be truncated. Import the clips that were read?"
            // Cancel first so Return defaults to the safe choice for a tampered/truncated file.
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Import Anyway")
            guard alert.runModal() == .alertSecondButtonReturn else {
                throw ExportImportError.importCancelled
            }
        }

        let imported = try restore(payload, container: container)
        FeedbackHUD.shared.show("Imported \(clips(imported))",
                                systemImage: "square.and.arrow.down")
        return imported
    }

    static func presentSavePanel(_ source: URL, itemCount: Int) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "QuietClipboard-export.qcclips"
        panel.allowedContentTypes = [.quietClipboardBackup]
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            // Hop explicitly: the SDK does not guarantee a MainActor-annotated
            // completion handler, and the HUD is main-actor only.
            Task { @MainActor in
                do {
                    try? FileManager.default.removeItem(at: dest)
                    try FileManager.default.copyItem(at: source, to: dest)
                    FeedbackHUD.shared.show("Exported \(clips(itemCount))",
                                            systemImage: "square.and.arrow.up")
                } catch {
                    FeedbackHUD.shared.show("Export failed",
                                            systemImage: "exclamationmark.triangle.fill",
                                            isWarning: true, duration: 2.0)
                }
            }
        }
    }

    static func presentOpenPanel(completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        // Accept both the compressed container and legacy plain-JSON exports.
        panel.allowedContentTypes = [.quietClipboardBackup, .json]
        panel.allowsMultipleSelection = false
        panel.begin { response in
            completion(response == .OK ? panel.url : nil)
        }
    }

    // MARK: - Internals

    private static func buildPayload(container: ModelContainer) throws -> ExportPayload {
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
        return ExportPayload(version: ExportPayload.currentVersion, exportedAt: .now,
                             itemCount: exportedItems.count,
                             items: exportedItems, categories: exportedCats,
                             pinnedSlots: pinnedRaw.isEmpty ? nil : pinnedRaw)
    }

    /// CPU-heavy half of export. `nonisolated` so it can run on a detached task.
    private nonisolated static func writeBackup(_ payload: ExportPayload) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        // No .prettyPrinted: indentation bloats the JSON before compression and the
        // file is no longer meant to be read by hand. sortedKeys keeps output stable
        // for diffing two backups.
        encoder.outputFormatting = [.sortedKeys]
        let json = try encoder.encode(payload)

        var data = backupMagic
        data.append(try (json as NSData).compressed(using: .zlib) as Data)

        // UUID + atomic write: two overlapping exports (double-clicked button) must not race
        // on the same temp path and hand the save panel a truncated file.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuietClipboard-\(UUID().uuidString).qcclips")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Backup files are untrusted input (users share them between Macs), so both sides of the
    /// inflate are bounded: a crafted few-MB DEFLATE stream can otherwise expand ~1000:1 into
    /// gigabytes in a single allocation and take the app down before any alert appears.
    private nonisolated static let maxRawBackupBytes = 256 * 1024 * 1024
    private nonisolated static let maxInflatedBackupBytes = 1024 * 1024 * 1024

    /// Sniffs the container format rather than trusting the file extension: a
    /// `QCBK1` prefix means deflated JSON; anything else is decoded as a legacy
    /// plain-JSON export.
    private nonisolated static func decodePayload(contentsOf url: URL) throws -> ExportPayload {
        if let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue,
           size > maxRawBackupBytes {
            throw ExportImportError.fileTooLarge
        }
        let raw = try Data(contentsOf: url)
        guard raw.count <= maxRawBackupBytes else { throw ExportImportError.fileTooLarge }
        let isContainer = raw.starts(with: backupMagic)

        let json: Data
        if isContainer {
            // Rebase the slice — the inflater binds the buffer from index 0.
            let deflated = Data(raw.dropFirst(backupMagic.count))
            json = try boundedInflate(deflated, limit: maxInflatedBackupBytes)
        } else {
            json = raw
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(ExportPayload.self, from: json)
        } catch {
            // A container that inflates but fails to decode is damage, not a format
            // mismatch; legacy JSON keeps the decoder's own error for diagnostics.
            if isContainer { throw ExportImportError.corruptArchive }
            throw error
        }
    }

    /// Streaming zlib (raw DEFLATE) inflate with an output ceiling — matches what
    /// `NSData.compressed(using: .zlib)` writes, but aborts as soon as the produced output
    /// exceeds `limit` instead of materializing an attacker-chosen allocation.
    private nonisolated static func boundedInflate(_ deflated: Data, limit: Int) throws -> Data {
        let streamPtr = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { streamPtr.deallocate() }
        guard compression_stream_init(streamPtr, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK else {
            throw ExportImportError.corruptArchive
        }
        defer { compression_stream_destroy(streamPtr) }

        let chunkSize = 512 * 1024
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: chunkSize)
        defer { dstBuffer.deallocate() }

        var output = Data()
        try deflated.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
            guard let srcBase = src.bindMemory(to: UInt8.self).baseAddress else {
                throw ExportImportError.corruptArchive
            }
            streamPtr.pointee.src_ptr = srcBase
            streamPtr.pointee.src_size = deflated.count
            while true {
                streamPtr.pointee.dst_ptr = dstBuffer
                streamPtr.pointee.dst_size = chunkSize
                let status = compression_stream_process(streamPtr, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                guard status == COMPRESSION_STATUS_OK || status == COMPRESSION_STATUS_END else {
                    throw ExportImportError.corruptArchive
                }
                let produced = chunkSize - streamPtr.pointee.dst_size
                if produced > 0 {
                    guard output.count + produced <= limit else { throw ExportImportError.fileTooLarge }
                    output.append(dstBuffer, count: produced)
                }
                if status == COMPRESSION_STATUS_END { break }
                // OK with no progress and no input left means a truncated stream.
                if produced == 0, streamPtr.pointee.src_size == 0 {
                    throw ExportImportError.corruptArchive
                }
            }
        }
        return output
    }

    private static func restore(_ payload: ExportPayload, container: ModelContainer) throws -> Int {
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

    private nonisolated static func clips(_ n: Int) -> String {
        "\(n) clip\(n == 1 ? "" : "s")"
    }
}
