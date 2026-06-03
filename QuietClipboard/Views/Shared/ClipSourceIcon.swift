import SwiftUI
import AppKit

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
                  let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
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
