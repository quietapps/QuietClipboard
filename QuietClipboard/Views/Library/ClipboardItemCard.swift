import SwiftUI
import AppKit

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ClipboardItemPreview(item: item)
                    .frame(height: 120)
                    .clipped()

                HStack(spacing: 4) {
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .padding(4)
                            .background(.thinMaterial, in: Circle())
                    }
                    typeBadge
                }
                .padding(6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? item.textContent ?? "Untitled")
                    .font(.system(.callout, design: item.contentType == .code ? .monospaced : .default))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    appIcon
                    Text(item.sourceAppName ?? "Unknown")
                        .font(.caption2)
                        .lineLimit(1)
                    Spacer()
                    Text(DateFormatting.relativeString(from: item.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2),
                        lineWidth: isSelected ? 2 : 0.5)
        )
        .animation(.spring(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.contentType.displayName) clip from \(item.sourceAppName ?? "unknown app")")
        .accessibilityValue(item.title ?? item.textContent ?? "")
        .accessibilityAddTraits(.isButton)
    }

    private var typeBadge: some View {
        Image(systemName: item.contentType.systemImage)
            .font(.caption2)
            .padding(4)
            .background(.thinMaterial, in: Circle())
    }

    @ViewBuilder
    private var appIcon: some View {
        if let bid = item.sourceAppBundleID,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            Image(nsImage: icon)
                .resizable()
                .frame(width: 12, height: 12)
        } else {
            Image(systemName: "app.dashed")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ClipboardItemPreview(item: item)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? item.textContent ?? "Untitled")
                    .font(.system(.body, design: item.contentType == .code ? .monospaced : .default))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: item.contentType.systemImage).font(.caption2)
                    Text(item.contentType.displayName).font(.caption2)
                    Text("·").font(.caption2)
                    Text(item.sourceAppName ?? "Unknown").font(.caption2)
                    Text("·").font(.caption2)
                    Text(DateFormatting.relativeString(from: item.createdAt)).font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            if item.isFavorite {
                Image(systemName: "star.fill").foregroundStyle(.yellow)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
    }
}
