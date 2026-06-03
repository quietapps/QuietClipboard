import SwiftUI

struct ClipboardItemPreview: View {
    let item: ClipboardItem
    /// Use compact redaction (lock only) for small preview areas such as popup grid cells.
    var compactRedaction: Bool = false
    /// Use larger icons for spacious card previews (library grid tiles, detail panel).
    var largeIcons: Bool = false
    /// When false, images use .fit (show full image, maintain aspect ratio). Default true = .fill (crop to frame).
    var fillImages: Bool = true
    /// Background color for letterbox areas. Defaults to system control background.
    var backgroundColor: Color = Color(nsColor: .controlBackgroundColor)

    var body: some View {
        SensitiveContentGate(item: item, compact: compactRedaction) {
            previewContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var previewContent: some View {
        Group {
            switch item.contentType {
            case .image, .screenshot:
                if let data = item.thumbnailData ?? item.content as Data?,
                   let nsImage = NSImage(data: data) {
                    if fillImages {
                        GeometryReader { geo in
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        }
                    } else {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    placeholder
                }
            case .color:
                if let hex = item.colorHex ?? item.textContent, let color = Color(hex: hex) {
                    ZStack(alignment: .bottomLeading) {
                        color
                        Text(hex)
                            .font(.system(largeIcons ? .body : .caption2, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                            .padding(largeIcons ? 12 : 6)
                    }
                } else {
                    placeholder
                }
            case .file:
                VStack(spacing: 6) {
                    Image(systemName: "doc")
                        .font(.system(size: largeIcons ? 56 : 28))
                    Text(item.title ?? "File")
                        .font(largeIcons ? .caption : .caption2)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .link:
                LinkFaviconView(item: item, iconSize: largeIcons ? 72 : 36)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .richText, .markdown:
                richTextPreview
            default:
                if let summary = item.resolvedText ?? item.title, !summary.isEmpty {
                    Text(summary)
                        .font(.system(largeIcons ? .callout : .caption, design: item.contentType == .code ? .monospaced : .default))
                        .lineLimit(largeIcons ? nil : 4)
                        .multilineTextAlignment(.leading)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    styledContentPlaceholder
                }
            }
        }
    }

    @ViewBuilder
    private var richTextPreview: some View {
        if let attr = RichContentRenderer.attributedPreview(for: item), attr.length > 0 {
            AttributedTextPreview(attributedString: attr)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let summary = item.displaySummary
            if summary != "Untitled", summary != "Rich text", summary != "Clipboard content" {
            Text(summary)
                .font(.system(largeIcons ? .callout : .caption))
                .lineLimit(largeIcons ? nil : 4)
                .multilineTextAlignment(.leading)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                styledContentPlaceholder
            }
        }
    }

    private var styledContentPlaceholder: some View {
        VStack(spacing: 6) {
            Image(systemName: item.contentType.systemImage)
                .font(.system(size: largeIcons ? 32 : 20))
            Text(item.contentType == .richText ? "Rich text" : "Styled content")
                .font(largeIcons ? .caption : .caption2)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholder: some View {
        Image(systemName: item.contentType.systemImage)
            .font(.system(size: largeIcons ? 48 : 24))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 || s.count == 3 else { return nil }
        if s.count == 3 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        var v: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&v) else { return nil }
        let r, g, b, a: Double
        if s.count == 8 {
            r = Double((v >> 24) & 0xff) / 255
            g = Double((v >> 16) & 0xff) / 255
            b = Double((v >> 8) & 0xff) / 255
            a = Double(v & 0xff) / 255
        } else {
            r = Double((v >> 16) & 0xff) / 255
            g = Double((v >> 8) & 0xff) / 255
            b = Double(v & 0xff) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
