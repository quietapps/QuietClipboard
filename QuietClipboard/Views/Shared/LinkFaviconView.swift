import SwiftUI
import AppKit

/// Favicon or host fallback for link clipboard items.
struct LinkFaviconView: View {
    let item: ClipboardItem
    var iconSize: CGFloat = 32

    private var cornerRadius: CGFloat { iconSize * 0.22 }
    private var contentInset: CGFloat { iconSize * 0.16 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)

            faviconContent
                .padding(contentInset)
        }
        .frame(width: iconSize, height: iconSize)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var faviconContent: some View {
        if let data = item.thumbnailData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: iconSize - contentInset * 2,
                       maxHeight: iconSize - contentInset * 2)
        } else if let host = LinkPreviewService.displayHost(from: item.textContent) {
            HostBadge(host: host, size: iconSize - contentInset * 2)
        } else {
            Image(systemName: "link")
                .font(.system(size: iconSize * 0.38))
                .foregroundStyle(.secondary)
        }
    }
}

private struct HostBadge: View {
    let host: String
    let size: CGFloat

    private var initial: String {
        String(host.prefix(1)).uppercased()
    }

    private var tint: Color {
        let hash = host.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) % 360 }
        return Color(hue: Double(hash) / 360.0, saturation: 0.45, brightness: 0.85)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.25))
            Text(initial)
                .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}
