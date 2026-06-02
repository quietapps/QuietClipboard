import Foundation
import LinkPresentation
import AppKit

struct LinkPreviewResult: Sendable {
    var title: String?
    var description: String?
    var imageData: Data?
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

        let imageData = await loadImageData(metadata.imageProvider)
        let result = LinkPreviewResult(
            title: metadata.title,
            description: metadata.value(forKey: "_summary") as? String,
            imageData: imageData
        )
        await cache.set(url, result)
        return result
    }

    private static func loadImageData(_ provider: NSItemProvider?) async -> Data? {
        guard let provider else { return nil }
        return await withCheckedContinuation { cont in
            provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                if let data {
                    cont.resume(returning: data)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
