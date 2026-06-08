import AppKit
import Foundation
import SwiftData
import CryptoKit

/// Prevents two concurrent backgroundIngest tasks from inserting the same content.
private actor IngestLock {
    private var active: Set<String> = []
    func tryLock(_ hash: String) -> Bool {
        guard !active.contains(hash) else { return false }
        active.insert(hash)
        return true
    }
    func unlock(_ hash: String) { active.remove(hash) }
}

@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published var isPaused: Bool = false
    @Published var pauseUntil: Date? = nil

    let modelContainer: ModelContainer  // `let` allows nonisolated access (Sendable)
    private var monitorTask: Task<Void, Never>?
    private var pauseTimer: Timer?
    private var watchdogTimer: Timer?
    private var lastTickAt = Date.now
    private var lastChangeCount: Int
    // Written only from MainActor; read on bg by passing snapshot value
    private(set) var lastContentHash: String?
    private nonisolated let ingestLock = IngestLock()

    // Max raw content stored — larger content stored as thumbnail only
    private nonisolated(unsafe) static let maxRawBytes = 8 * 1024 * 1024  // 8 MB
    private nonisolated(unsafe) static let maxTextBytes = 512 * 1024       // 512 KB
    // Oversized images are downscaled to this max dimension (still a usable paste, not a tiny thumb)
    private nonisolated(unsafe) static let maxStoredImageDimension: CGFloat = 2048

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        guard monitorTask == nil else { return }
        lastTickAt = .now
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.tick()
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        startWatchdog()
    }

    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    /// Restarts the poll loop if it ever stalls (e.g. a hung await), so capture can't silently die.
    private func startWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkWatchdog() }
        }
    }

    private func checkWatchdog() {
        guard monitorTask != nil, !isPaused else { return }
        guard Date.now.timeIntervalSince(lastTickAt) > 5 else { return }
        NSLog("ClipboardMonitor watchdog: polling stalled — restarting")
        monitorTask?.cancel()
        monitorTask = nil
        start()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if !paused {
            pauseTimer?.invalidate()
            pauseTimer = nil
            pauseUntil = nil
        }
    }

    func pause(for seconds: TimeInterval) {
        let target = Date().addingTimeInterval(seconds)
        isPaused = true
        pauseUntil = target
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: max(1, seconds), repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.setPaused(false) }
        }
    }

    func pauseUntilTomorrow() {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.day! += 1
        comps.hour = 0; comps.minute = 0; comps.second = 0
        if let tomorrow = Calendar.current.date(from: comps) {
            pause(for: max(1, tomorrow.timeIntervalSinceNow))
        }
    }

    func acknowledgeUserCopy(contentHash: String) {
        lastContentHash = contentHash
        lastChangeCount = NSPasteboard.general.changeCount
    }

    /// Call right after the app itself writes the pasteboard (paste/copy from history) so the
    /// monitor recognizes its own write and skips it on the next tick. Lightweight on purpose —
    /// this runs on the main thread during every paste/copy; doing a full snapshot + thumbnail
    /// here would freeze the UI on large images. The `changeCount` check alone reliably
    /// suppresses the immediate self-write; the DB content-hash dedup in `backgroundIngest`
    /// catches anything that slips through.
    func acknowledgeOwnPasteboardWrite() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    // Snapshot of @MainActor Preferences values — captured before leaving main thread
    struct CaptureSettings: Sendable {
        let isTypeCaptured: @Sendable (ClipboardContentType) -> Bool
        let sensitiveDetectionEnabled: Bool
        let sensitiveBehavior: SensitiveBehavior
        let autoCategorizationEnabled: Bool
        let autoCategorizationML: Bool
        let captureUniversalClipboard: Bool
        let excludedBundleIDs: Set<String>
        let screenPixelSizes: [CGSize]

        @MainActor
        init() {
            self.screenPixelSizes = NSScreen.screens.map {
                CGSize(width: $0.frame.width * $0.backingScaleFactor,
                       height: $0.frame.height * $0.backingScaleFactor)
            }
            self.sensitiveDetectionEnabled  = Preferences.sensitiveDetectionEnabled
            self.sensitiveBehavior          = Preferences.sensitiveBehavior
            self.autoCategorizationEnabled  = Preferences.autoCategorizationEnabled
            self.autoCategorizationML       = Preferences.autoCategorizationML
            self.captureUniversalClipboard  = Preferences.captureUniversalClipboard
            self.excludedBundleIDs          = Preferences.excludedBundleIDs
            // Gate on BOTH the group master switch and the per-type set — mirror
            // Preferences.isTypeCaptured. Capturing the two Sets by value keeps this @Sendable.
            let captured                    = Preferences.capturedTypes
            let groups                      = Preferences.enabledCaptureGroups
            self.isTypeCaptured             = { type in
                groups.contains(type.captureGroup) && captured.contains(type)
            }
        }
    }

    // MARK: - Tick (main thread — NSPasteboard requires it)

    private func tick() async {
        lastTickAt = .now
        let pb = NSPasteboard.general
        let current = pb.changeCount
        if isPaused { lastChangeCount = current; return }
        if current == lastChangeCount { return }
        lastChangeCount = current

        let snap = PasteboardHelper.snapshot(pb)
        guard !snap.isConcealed, !snap.isTransient else { return }

        // Yield after the blocking pasteboard IPC read (can be 20-100ms for large images)
        // so any shortcut handler queued during that read runs immediately, before the
        // rest of tick()'s work. The new item gets ingested concurrently via Task.detached.
        await Task.yield()

        let settings = CaptureSettings()
        guard !snap.isUniversalClipboard || settings.captureUniversalClipboard else { return }

        let frontApp = NSWorkspace.shared.frontmostApplication
        var bundleID = frontApp?.bundleIdentifier
        var appName  = frontApp?.localizedName

        if snap.isUniversalClipboard {
            bundleID = UniversalClipboardBridge.syntheticBundleID
            appName  = snap.universalClipboardDeviceName ?? "iPhone/iPad"
        } else if let bid = bundleID, settings.excludedBundleIDs.contains(bid) {
            return
        }

        let priorHash = lastContentHash

        Task.detached(priority: .utility) { [weak self] in
            await self?.backgroundIngest(
                snap: snap, bundleID: bundleID, appName: appName,
                priorHash: priorHash, settings: settings
            )
        }
    }

    // MARK: - Background ingest (nonisolated — runs off main thread)

    nonisolated private func backgroundIngest(
        snap: PasteboardSnapshot,
        bundleID: String?,
        appName: String?,
        priorHash: String?,
        settings: CaptureSettings
    ) async {
        var type = ContentTypeDetector.detect(snap)
        // Full-screen captures match a display's exact pixel size — tag them as screenshots so
        // the Screenshots section/filter/retention are actually reachable. Region grabs that don't
        // match a screen stay `.image` (no reliable clipboard marker exists for those).
        if type == .image,
           let raw = snap.png ?? snap.tiff,
           let size = ThumbnailGenerator.pixelSize(forImageData: raw),
           settings.screenPixelSizes.contains(where: {
               abs($0.width - size.width) < 2 && abs($0.height - size.height) < 2
           }) {
            type = .screenshot
        }
        guard settings.isTypeCaptured(type) else { return }
        guard let payload = Self.buildPayload(snap: snap, type: type) else { return }

        let hash = Self.hash(payload.content)
        guard hash != priorHash else { return }
        guard await ingestLock.tryLock(hash) else { return }
        defer { Task { await self.ingestLock.unlock(hash) } }

        let title       = ContentTypeDetector.title(for: snap, type: type)
        let colorHex    = type == .color ? ColorParsing.hexFrom(snap.string ?? "") : nil
        let fingerprint = DuplicateDetectionService.normalizedFingerprint(
            text: payload.text, contentType: type, contentHash: hash
        )

        var isSensitive = false
        if settings.sensitiveDetectionEnabled {
            if let text = payload.text {
                isSensitive = SensitiveDetector.isSensitive(text, isConcealed: snap.isConcealed)
            } else if snap.isConcealed {
                isSensitive = true
            }
            if isSensitive, settings.sensitiveBehavior == .skip { return }
        }
        let saveHidden = isSensitive && settings.sensitiveBehavior == .saveHidden

        let context = ModelContext(modelContainer)
        var existingDesc = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.contentHash == hash }
        )
        existingDesc.fetchLimit = 1

        let resultID: UUID?
        let wasInsert: Bool
        let now = Date.now

        if let existing = (try? context.fetch(existingDesc))?.first {
            existing.copyCount   += 1
            existing.lastCopiedAt = now
            existing.modifiedAt   = now
            if snap.isUniversalClipboard {
                existing.sourceAppBundleID = bundleID
                existing.sourceAppName     = appName
            } else {
                if existing.sourceAppBundleID == nil { existing.sourceAppBundleID = bundleID }
                if existing.sourceAppName     == nil { existing.sourceAppName     = appName  }
            }
            let event = ClipboardCopyEvent(copiedAt: now, sourceAppBundleID: bundleID, sourceAppName: appName)
            event.item = existing
            existing.copyEvents.append(event)
            context.insert(event)
            do { try context.save(); resultID = existing.id; wasInsert = false }
            catch { NSLog("Dup save failed: \(error)"); resultID = nil; wasInsert = false }
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
                isSensitive: saveHidden
            )
            item.normalizedFingerprint = fingerprint
            item.applyStructuredDataDetection()

            let event = ClipboardCopyEvent(copiedAt: now, sourceAppBundleID: bundleID, sourceAppName: appName)
            event.item = item
            item.copyEvents.append(event)
            context.insert(event)
            DuplicateDetectionService.assignNearDuplicateGroup(item: item, context: context)
            context.insert(item)
            do { try context.save(); resultID = item.id; wasInsert = true }
            catch { NSLog("Insert save failed: \(error)"); resultID = nil; wasInsert = false }
        }

        let saveFailed = (resultID == nil)
        await MainActor.run { [weak self] in
            self?.lastContentHash = hash
            if saveFailed {
                // Surface lost clips instead of failing silently. `lastContentHash` is set
                // above, so this fires at most once per distinct clip — no per-poll spam.
                FeedbackHUD.shared.show("Couldn’t save the last copied item",
                                        systemImage: "exclamationmark.triangle.fill",
                                        isWarning: true,
                                        duration: 2.2)
            } else if wasInsert {
                if saveHidden { CaptureFeedbackSound.playSensitiveCapture() }
                else          { CaptureFeedbackSound.playNewCapture() }
            }
        }

        if wasInsert, let id = resultID {
            Task.detached(priority: .background) { [weak self] in
                await self?.enrich(itemID: id, type: type, snap: snap, payload: payload,
                                   settings: settings)
                await self?.autoCategorize(itemID: id, settings: settings)
            }
        }
    }

    // MARK: - Auto-categorization

    nonisolated private func autoCategorize(itemID: UUID, settings: CaptureSettings) async {
        guard settings.autoCategorizationEnabled else { return }
        await MainActor.run {
            let ctx = ModelContext(modelContainer)
            var d = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == itemID })
            d.fetchLimit = 1
            guard let item = (try? ctx.fetch(d))?.first else { return }

            let suggestions = CategorySuggestionService.suggest(for: item, useML: settings.autoCategorizationML)
            guard !suggestions.isEmpty else { return }

            let remaining: [CategorySuggestion]
            if Preferences.autoCategorizationAutoApply {
                remaining = CategorySuggestionService.autoApply(
                    suggestions: suggestions,
                    to: item,
                    context: ctx,
                    threshold: Preferences.autoCategorizationAutoApplyThreshold
                )
            } else {
                remaining = suggestions
            }
            if !remaining.isEmpty, item.pendingSuggestions.isEmpty {
                item.setPendingSuggestions(remaining)
            }
            item.modifiedAt = .now
            try? ctx.save()
        }
    }

    // MARK: - Enrichment

    nonisolated private func enrich(
        itemID: UUID, type: ClipboardContentType,
        snap: PasteboardSnapshot, payload: Payload,
        settings: CaptureSettings
    ) async {
        switch type {
        case .image, .screenshot:
            if let ocr = await OCRService.recognizeText(in: payload.content) {
                await applyUpdate(itemID: itemID) { item in
                    item.ocrText = ocr
                }
            }
        case .link:
            guard let s = snap.string,
                  let url = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)),
                  url.scheme?.lowercased().hasPrefix("http") == true else { return }
            if let result = await LinkPreviewService.fetch(url) {
                await applyUpdate(itemID: itemID) {
                    $0.linkPreviewTitle       = result.title
                    $0.linkPreviewDescription = result.description
                    $0.linkPreviewImageData   = result.imageData
                    if let t = result.title, !t.isEmpty { $0.title = t }
                }
            }
            if let iconData = await LinkPreviewService.fetchFavicon(for: url) {
                await applyUpdate(itemID: itemID) {
                    $0.thumbnailData = LinkPreviewService.faviconThumbnailData(from: iconData) ?? iconData
                }
            }
        default:
            break
        }
    }

    nonisolated private func applyUpdate(itemID: UUID, mutate: @Sendable (ClipboardItem) -> Void) async {
        let context = ModelContext(modelContainer)
        var desc = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == itemID })
        desc.fetchLimit = 1
        guard let item = (try? context.fetch(desc))?.first else { return }
        mutate(item)
        item.modifiedAt = .now
        try? context.save()
    }

    // MARK: - Payload building (nonisolated — runs on background thread)

    struct Payload {
        var content: Data
        var text: String?
        var thumbnail: Data?
        var fileSize: Int64?
        var mime: String?
    }

    nonisolated private static func buildPayload(snap: PasteboardSnapshot, type: ClipboardContentType) -> Payload? {
        switch type {
        case .image, .screenshot:
            guard let raw = snap.png ?? snap.tiff else { return nil }
            let thumb = ThumbnailGenerator.thumbnail(forImageData: raw)  // CGContext — thread-safe
            // Always store valid PNG so the pasteboard `.png` write is correct. For oversized
            // images, downscale to a usable size (not the tiny UI thumbnail) so paste still
            // yields a real image rather than a 200px crop.
            let stored: Data
            if raw.count > maxRawBytes {
                stored = ThumbnailGenerator.pngData(forImageData: raw, maxDimension: maxStoredImageDimension)
                    ?? thumb ?? raw
            } else if snap.png != nil {
                stored = raw                                                   // already PNG
            } else {
                stored = ThumbnailGenerator.pngData(forImageData: raw) ?? raw  // TIFF → PNG
            }
            return Payload(content: stored, text: nil, thumbnail: thumb,
                           fileSize: Int64(raw.count), mime: "image/png")

        case .file:
            guard let url = snap.fileURLs.first else { return nil }
            let data  = Data(url.path.utf8)
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size  = (attrs?[.size] as? NSNumber)?.int64Value
            return Payload(content: data, text: url.absoluteString,
                           thumbnail: nil, fileSize: size, mime: nil)

        case .richText:
            if let rtfd = snap.rtfd {
                let capped = rtfd.count > maxRawBytes ? rtfd.prefix(maxRawBytes) : rtfd[...]
                let plain = plainText(from: snap)
                return Payload(content: Data(capped), text: plain,
                               thumbnail: nil, fileSize: nil, mime: "application/rtfd")
            }
            if let rtf = snap.rtf {
                let capped = rtf.count > maxRawBytes ? rtf.prefix(maxRawBytes) : rtf[...]
                let plain = plainText(from: snap)
                return Payload(content: Data(capped), text: plain,
                               thumbnail: nil, fileSize: nil, mime: "text/rtf")
            }
            if let html = snap.html, let htmlData = html.data(using: .utf8) {
                let capped = htmlData.count > maxRawBytes ? htmlData.prefix(maxRawBytes) : htmlData[...]
                let plain = plainText(from: snap)
                return Payload(content: Data(capped), text: plain,
                               thumbnail: nil, fileSize: nil, mime: "text/html")
            }
            if let archive = snap.archiveData {
                return Payload(content: archive, text: plainText(from: snap),
                               thumbnail: nil, fileSize: nil, mime: PasteboardHelper.archiveMIME)
            }
            if let s = snap.string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                return Payload(content: Data(s.utf8), text: s, thumbnail: nil, fileSize: nil, mime: "text/plain")
            }
            return nil

        case .color:
            if let s = snap.string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                // Normalize hex to #RRGGBB for content so "E60EC9" and "#E60EC9" hash
                // identically and deduplicate correctly. Original text preserved for display.
                let normalized = ColorParsing.hexFrom(s) ?? s
                return Payload(content: Data(normalized.utf8), text: s,
                               thumbnail: nil, fileSize: nil, mime: "text/plain")
            }
            return richFallbackPayload(from: snap)

        case .text, .markdown, .code, .link, .svg:
            if let s = snap.string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                let text = s.count > 500_000 ? String(s.prefix(500_000)) : s
                return Payload(content: Data(text.utf8), text: text,
                               thumbnail: nil, fileSize: nil, mime: "text/plain")
            }
            return richFallbackPayload(from: snap)

        case .other:
            if let archive = snap.archiveData {
                return Payload(content: archive, text: plainText(from: snap),
                               thumbnail: nil, fileSize: nil, mime: PasteboardHelper.archiveMIME)
            }
            return richFallbackPayload(from: snap)
        }
    }

    nonisolated private static func plainText(from snap: PasteboardSnapshot) -> String? {
        guard let s = snap.string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return nil
        }
        return s.count > 500_000 ? String(s.prefix(500_000)) : s
    }

    nonisolated private static func richFallbackPayload(from snap: PasteboardSnapshot) -> Payload? {
        if let rtfd = snap.rtfd {
            let capped = rtfd.count > maxRawBytes ? rtfd.prefix(maxRawBytes) : rtfd[...]
            return Payload(content: Data(capped), text: plainText(from: snap),
                           thumbnail: nil, fileSize: nil, mime: "application/rtfd")
        }
        if let rtf = snap.rtf {
            let capped = rtf.count > maxRawBytes ? rtf.prefix(maxRawBytes) : rtf[...]
            return Payload(content: Data(capped), text: plainText(from: snap),
                           thumbnail: nil, fileSize: nil, mime: "text/rtf")
        }
        if let html = snap.html, let htmlData = html.data(using: .utf8) {
            let capped = htmlData.count > maxRawBytes ? htmlData.prefix(maxRawBytes) : htmlData[...]
            return Payload(content: Data(capped), text: plainText(from: snap),
                           thumbnail: nil, fileSize: nil, mime: "text/html")
        }
        if let archive = snap.archiveData {
            return Payload(content: archive, text: plainText(from: snap),
                           thumbnail: nil, fileSize: nil, mime: PasteboardHelper.archiveMIME)
        }
        return nil
    }

    nonisolated private static func hash(_ d: Data) -> String {
        let digest = SHA256.hash(data: d)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
