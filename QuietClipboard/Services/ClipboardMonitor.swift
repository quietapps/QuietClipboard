import AppKit
import Foundation
import SwiftData
import CryptoKit

@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published var isPaused: Bool = false

    private let modelContainer: ModelContainer
    private var task: Task<Void, Never>?
    private var lastChangeCount: Int
    private var lastContentHash: String?

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    private func tick() async {
        let pb = NSPasteboard.general
        let current = pb.changeCount
        if isPaused {
            lastChangeCount = current
            return
        }
        if current == lastChangeCount { return }
        lastChangeCount = current

        let snap = PasteboardHelper.snapshot(pb)
        if snap.isConcealed { return }

        let frontApp = NSWorkspace.shared.frontmostApplication
        let bundleID = frontApp?.bundleIdentifier
        let appName = frontApp?.localizedName

        if let bid = bundleID, Preferences.excludedBundleIDs.contains(bid) { return }

        await ingest(snap: snap, bundleID: bundleID, appName: appName)
    }

    private func ingest(snap: PasteboardSnapshot, bundleID: String?, appName: String?) async {
        let type = ContentTypeDetector.detect(snap)

        if !Preferences.capturedTypes.contains(type) { return }

        guard let payload = makePayload(snap: snap, type: type) else { return }

        let hash = Self.hash(payload.content)
        if hash == lastContentHash { return }

        let title = ContentTypeDetector.title(for: snap, type: type)
        let colorHex = type == .color ? ColorParsing.hexFrom(snap.string ?? "") : nil

        var isSensitive = false
        if Preferences.sensitiveDetectionEnabled {
            if let text = payload.text {
                isSensitive = SensitiveDetector.isSensitive(text, isConcealed: snap.isConcealed)
            } else if snap.isConcealed {
                isSensitive = true
            }
            if isSensitive, Preferences.sensitiveBehavior == .skip { return }
        }

        let context = ModelContext(modelContainer)
        var existingDesc = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.contentHash == hash }
        )
        existingDesc.fetchLimit = 1

        let resultID: UUID?
        let wasInsert: Bool
        if let existing = (try? context.fetch(existingDesc))?.first {
            existing.createdAt = .now
            existing.modifiedAt = .now
            if existing.sourceAppBundleID == nil { existing.sourceAppBundleID = bundleID }
            if existing.sourceAppName == nil { existing.sourceAppName = appName }
            do { try context.save(); resultID = existing.id; wasInsert = false }
            catch { NSLog("Reorder save failed: \(error)"); resultID = nil; wasInsert = false }
        } else {
            let item = ClipboardItem(
                content: payload.content,
                contentHash: hash,
                contentType: type,
                textContent: payload.text,
                title: title,
                sourceAppBundleID: bundleID,
                sourceAppName: appName,
                thumbnailData: payload.thumbnail,
                colorHex: colorHex,
                fileSize: payload.fileSize,
                fileMIMEType: payload.mime,
                isSensitive: isSensitive
            )
            context.insert(item)
            do { try context.save(); resultID = item.id; wasInsert = true }
            catch { NSLog("Insert save failed: \(error)"); resultID = nil; wasInsert = false }
        }

        lastContentHash = hash

        if wasInsert, let id = resultID {
            Task.detached { [weak self] in
                await self?.enrich(itemID: id, type: type, snap: snap, payload: payload)
            }
        }
    }

    private func enrich(itemID: UUID, type: ClipboardContentType,
                        snap: PasteboardSnapshot, payload: Payload) async {
        switch type {
        case .image, .screenshot:
            if let ocr = await OCRService.recognizeText(in: payload.content) {
                await applyUpdate(itemID: itemID) { $0.ocrText = ocr }
            }
        case .link:
            guard let s = snap.string,
                  let url = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let scheme = url.scheme,
                  scheme.lowercased().hasPrefix("http") else { return }
            if let result = await LinkPreviewService.fetch(url) {
                await applyUpdate(itemID: itemID) {
                    $0.linkPreviewTitle = result.title
                    $0.linkPreviewDescription = result.description
                    $0.linkPreviewImageData = result.imageData
                    if let t = result.title, !t.isEmpty { $0.title = t }
                }
            }
        default:
            break
        }
    }

    private func applyUpdate(itemID: UUID, mutate: (ClipboardItem) -> Void) async {
        await MainActor.run {
            let context = ModelContext(modelContainer)
            var desc = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate { $0.id == itemID }
            )
            desc.fetchLimit = 1
            guard let item = (try? context.fetch(desc))?.first else { return }
            mutate(item)
            item.modifiedAt = .now
            try? context.save()
        }
    }

    private struct Payload {
        var content: Data
        var text: String?
        var thumbnail: Data?
        var fileSize: Int64?
        var mime: String?
    }

    private func makePayload(snap: PasteboardSnapshot, type: ClipboardContentType) -> Payload? {
        switch type {
        case .image, .screenshot:
            let data = snap.png ?? snap.tiff
            guard let d = data else { return nil }
            let thumb = ThumbnailGenerator.thumbnail(forImageData: d)
            return Payload(content: d, text: nil, thumbnail: thumb,
                           fileSize: Int64(d.count), mime: "image/png")
        case .file:
            guard let url = snap.fileURLs.first else { return nil }
            let path = url.path
            let data = Data(path.utf8)
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            let size = (attrs?[.size] as? NSNumber)?.int64Value
            return Payload(content: data, text: url.absoluteString,
                           thumbnail: nil, fileSize: size, mime: nil)
        case .richText:
            guard let rtf = snap.rtf else {
                if let s = snap.string {
                    return Payload(content: Data(s.utf8), text: s, thumbnail: nil, fileSize: nil, mime: nil)
                }
                return nil
            }
            return Payload(content: rtf, text: snap.string, thumbnail: nil, fileSize: nil, mime: "text/rtf")
        case .text, .code, .link, .color, .svg, .other:
            guard let s = snap.string else { return nil }
            return Payload(content: Data(s.utf8), text: s, thumbnail: nil, fileSize: nil, mime: "text/plain")
        }
    }

    private static func hash(_ d: Data) -> String {
        let digest = SHA256.hash(data: d)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
