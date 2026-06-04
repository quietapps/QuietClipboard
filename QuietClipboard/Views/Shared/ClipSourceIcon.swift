import SwiftUI
import AppKit

/// Resolves and caches app icons by bundle ID. Launch Services + disk lookups are expensive and
/// were previously run for every visible cell on every render; icons are stable per session.
@MainActor
enum AppIconCache {
    private static var cache: [String: NSImage?] = [:]

    static func icon(forBundleID bid: String) -> NSImage? {
        if let cached = cache[bid] { return cached }
        let resolved = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        cache[bid] = resolved
        return resolved
    }
}

/// Source app icon, or Universal Clipboard device symbol.
struct ClipSourceIcon: View {
    let item: ClipboardItem
    var size: CGFloat = 12

    var body: some View {
        if item.isUniversalClipboardSource {
            Image(systemName: item.universalClipboardSystemImage)
                .font(.system(size: size))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        } else if let bid = item.sourceAppBundleID,
                  let icon = AppIconCache.icon(forBundleID: bid) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "app.dashed")
                .font(.system(size: size))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
}
