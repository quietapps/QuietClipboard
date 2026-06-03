import Foundation
import LinkPresentation
import AppKit

/// Resolves site favicons by trying the URL origin, then progressively longer path prefixes.
enum LinkFaviconResolver {
    private static let maxPathDepth = 4
    private actor FaviconCache {
        private var hits: [URL: Data] = [:]
        private var misses: Set<URL> = []

        func cached(_ url: URL) -> Data? {
            if let data = hits[url] { return data }
            if misses.contains(url) { return nil }
            return nil
        }

        func isKnown(_ url: URL) -> Bool {
            hits[url] != nil || misses.contains(url)
        }

        func store(_ url: URL, data: Data?) {
            if let data {
                hits[url] = data
                misses.remove(url)
            } else {
                misses.insert(url)
                hits.removeValue(forKey: url)
            }
        }
    }

    private static let cache = FaviconCache()

    /// Ordered origins to try: `https://host/`, then `https://host/segment/`, …
    static func originCandidates(from url: URL, maxPathDepth: Int = maxPathDepth) -> [URL] {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return [] }

        var seen = Set<String>()
        var result: [URL] = []

        func append(path: String) {
            let normalized = path.isEmpty ? "/" : (path.hasSuffix("/") ? path : "\(path)/")
            guard let built = URL(string: "\(scheme)://\(host)\(normalized)") else { return }
            let key = built.absoluteString
            guard seen.insert(key).inserted else { return }
            result.append(built)
        }

        append(path: "/")

        var built = ""
        for (index, segment) in url.path.split(separator: "/").map(String.init).filter({ !$0.isEmpty }).enumerated() {
            if index >= maxPathDepth { break }
            built += "/\(segment)"
            append(path: built)
        }

        return result
    }

    /// Favicon for a link URL; walks candidates from shortest origin to longer paths.
    static func fetchWithFallback(for url: URL) async -> Data? {
        for origin in originCandidates(from: url) {
            if await cache.isKnown(origin) {
                if let data = await cache.cached(origin) { return data }
                continue
            }
            if let data = await loadFavicon(from: origin) {
                await cache.store(origin, data: data)
                return data
            }
            await cache.store(origin, data: nil)
        }
        return nil
    }

    private static func loadFavicon(from origin: URL) async -> Data? {
        if let icon = await loadIconFromMetadata(origin) { return icon }
        return await loadFaviconICO(origin)
    }

    private static func loadIconFromMetadata(_ url: URL) async -> Data? {
        let metadata: LPLinkMetadata? = await withCheckedContinuation { cont in
            let provider = LPMetadataProvider()
            provider.timeout = 5
            provider.startFetchingMetadata(for: url) { meta, _ in
                cont.resume(returning: meta)
            }
        }
        guard let metadata else { return nil }
        return await loadImageData(metadata.iconProvider)
    }

    private static func loadFaviconICO(_ origin: URL) async -> Data? {
        guard var components = URLComponents(url: origin, resolvingAgainstBaseURL: false) else { return nil }
        components.path = "/favicon.ico"
        components.query = nil
        components.fragment = nil
        guard let faviconURL = components.url else { return nil }

        var request = URLRequest(url: faviconURL)
        request.timeoutInterval = 5
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200 ... 299).contains(http.statusCode),
                  !data.isEmpty,
                  NSImage(data: data) != nil else { return nil }
            return data
        } catch {
            return nil
        }
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
