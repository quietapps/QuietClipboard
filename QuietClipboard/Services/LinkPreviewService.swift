import Foundation
import LinkPresentation
import AppKit

struct LinkPreviewResult: Sendable {
    var title: String?
    var description: String?
    var imageData: Data?
    /// Site favicon / touch icon from `LPLinkMetadata.iconProvider`.
    var iconData: Data?
}

private actor LinkPreviewCache {
    private var cache: [URL: LinkPreviewResult] = [:]
    func get(_ url: URL) -> LinkPreviewResult? { cache[url] }
    func set(_ url: URL, _ result: LinkPreviewResult) { cache[url] = result }
}

enum LinkPreviewService {
    private static let cache = LinkPreviewCache()
    static var enabled: Bool {
        get { !UserDefaults.standard.bool(forKey: "QuietClipboard.LinkPreviewsDisabled") }
        set { UserDefaults.standard.set(!newValue, forKey: "QuietClipboard.LinkPreviewsDisabled") }
    }

    static func fetch(_ url: URL) async -> LinkPreviewResult? {
        guard enabled else { return nil }
        if let cached = await cache.get(url) { return cached }

        let metadata: LPLinkMetadata? = await withCheckedContinuation { cont in
            let provider = LPMetadataProvider()
            provider.timeout = 8
            provider.startFetchingMetadata(for: url) { meta, _ in
                cont.resume(returning: meta)
            }
        }
        guard let metadata else { return nil }

        var iconData = await loadImageData(metadata.iconProvider)
        if iconData == nil {
            iconData = await LinkFaviconResolver.fetchWithFallback(for: url)
        }
        let imageData = await loadImageData(metadata.imageProvider)
        let result = LinkPreviewResult(
            title: metadata.title,
            description: metadata.value(forKey: "_summary") as? String,
            imageData: imageData,
            iconData: iconData
        )
        await cache.set(url, result)
        return result
    }

    /// Favicon only (origin → path fallbacks). Use when enriching links after capture.
    static func fetchFavicon(for url: URL) async -> Data? {
        await LinkFaviconResolver.fetchWithFallback(for: url)
    }

    /// Host label for UI fallback when no favicon is cached (e.g. `apple.com`).
    static func displayHost(from urlString: String?) -> String? {
        guard let raw = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: raw),
              var host = url.host?.lowercased() else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host.isEmpty ? nil : host
    }

    static func faviconThumbnailData(from iconData: Data) -> Data? {
        ThumbnailGenerator.faviconTile(from: iconData, canvasSize: 64)
    }

    private static func loadImageData(_ provider: NSItemProvider?) async -> Data? {
        guard let provider else { return nil }
        let types = ["public.image", "public.png", "public.jpeg", "com.apple.icns"]
        for typeId in types where provider.hasItemConformingToTypeIdentifier(typeId) {
            if let data = await loadDataRepresentation(provider, typeId: typeId) {
                return data
            }
        }
        return await loadDataRepresentation(provider, typeId: "public.image")
    }

    private static func loadDataRepresentation(_ provider: NSItemProvider, typeId: String) async -> Data? {
        await withCheckedContinuation { cont in
            provider.loadDataRepresentation(forTypeIdentifier: typeId) { data, _ in
                cont.resume(returning: data)
            }
        }
    }
}
