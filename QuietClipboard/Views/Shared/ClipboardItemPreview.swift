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
    /// Extra bottom clearance for the color hex label so it doesn't overlap a card footer.
    var colorHexBottomInset: CGFloat = 0

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
                // Prefer the pre-generated thumbnail; only fault the full content blob when
                // no thumbnail exists yet (in-flight / legacy items). Decoding + downsampling
                // happens off the main thread and is cached, so list scrolling never blocks
                // on NSImage(data:) and large blobs aren't retained in the view tree.
                if let data = item.thumbnailData ?? item.content as Data? {
                    ClipImageView(
                        data: data,
                        cacheKey: "\(item.id.uuidString)-\(item.thumbnailData != nil ? "t" : "c")",
                        maxPixel: largeIcons ? 1024 : 512,
                        fill: fillImages,
                        placeholderSystemImage: item.contentType.systemImage,
                        largeIcons: largeIcons
                    )
                } else {
                    placeholder
                }
            case .color:
                if let colorSource = item.colorHex ?? item.textContent, let color = Color(hex: colorSource) {
                    ZStack(alignment: .bottomLeading) {
                        color
                        // Show original copied text; fall back to colorHex only if no textContent
                        Text(item.textContent ?? colorSource)
                            .font(.system(largeIcons ? .body : .caption2, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                            .padding(largeIcons ? 12 : 6)
                            .padding(.bottom, colorHexBottomInset)
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
        if largeIcons, let attr = RichContentRenderer.appearanceAdaptedPreview(for: item), attr.length > 0 {
            AttributedTextPreview(attributedString: attr)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let summary = item.resolvedText ?? item.displaySummary
            if !summary.isEmpty, summary != "Untitled", summary != "Rich text", summary != "Clipboard content" {
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

/// Decodes and downsamples image data off the main thread, caching the small result so
/// repeated renders (scroll reuse) are instant and large source blobs are never retained.
final class ThumbnailDecoder {
    static let shared = ThumbnailDecoder()

    private let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 300
        return c
    }()

    func cached(_ key: String) -> NSImage? { cache.object(forKey: key as NSString) }

    /// Decodes on a background queue and delivers the result on the main queue.
    func image(for data: Data,
               key: String,
               maxPixel: CGFloat,
               completion: @escaping (NSImage?) -> Void) {
        if let hit = cache.object(forKey: key as NSString) {
            completion(hit)
            return
        }
        let cache = self.cache
        DispatchQueue.global(qos: .userInitiated).async {
            let image = ThumbnailDecoder.downsample(data: data, maxPixel: maxPixel)
            if let image { cache.setObject(image, forKey: key as NSString) }
            DispatchQueue.main.async { completion(image) }
        }
    }

    private static func downsample(data: Data, maxPixel: CGFloat) -> NSImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return NSImage(data: data) // exotic formats ImageIO can't index
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return NSImage(data: data)
        }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}

/// Async, cached, downsampled image view used by clip previews.
struct ClipImageView: View {
    let data: Data
    let cacheKey: String
    let maxPixel: CGFloat
    var fill: Bool = true
    var placeholderSystemImage: String = "photo"
    var largeIcons: Bool = false

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                if fill {
                    GeometryReader { geo in
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                } else {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
            } else {
                Image(systemName: placeholderSystemImage)
                    .font(.system(size: largeIcons ? 48 : 24))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: load)
        .onChange(of: cacheKey) { _, _ in
            image = nil
            load()
        }
    }

    private func load() {
        if let hit = ThumbnailDecoder.shared.cached(cacheKey) {
            image = hit
            return
        }
        ThumbnailDecoder.shared.image(for: data, key: cacheKey, maxPixel: maxPixel) { decoded in
            image = decoded
        }
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
