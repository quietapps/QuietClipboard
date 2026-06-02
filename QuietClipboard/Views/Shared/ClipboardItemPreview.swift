import SwiftUI

struct ClipboardItemPreview: View {
    let item: ClipboardItem

    var body: some View {
        Group {
            switch item.contentType {
            case .image, .screenshot:
                if let data = item.thumbnailData ?? item.content as Data?,
                   let nsImage = NSImage(data: data) {
                    GeometryReader { geo in
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                } else {
                    placeholder
                }
            case .color:
                if let hex = item.colorHex, let color = Color(hex: hex) {
                    color
                } else {
                    placeholder
                }
            case .file:
                VStack(spacing: 4) {
                    Image(systemName: "doc")
                        .font(.system(size: 28))
                    Text(item.title ?? "File")
                        .font(.caption)
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .link:
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.linkPreviewTitle ?? item.title ?? item.textContent ?? "")
                        .font(.caption.bold())
                        .lineLimit(2)
                    Text(item.textContent ?? "")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            default:
                Text(item.textContent ?? item.title ?? "")
                    .font(.system(.caption, design: item.contentType == .code ? .monospaced : .default))
                    .lineLimit(6)
                    .multilineTextAlignment(.leading)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
    }

    private var placeholder: some View {
        Image(systemName: item.contentType.systemImage)
            .font(.system(size: 24))
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
