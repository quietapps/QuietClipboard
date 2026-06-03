import SwiftUI

struct ClipMetadataView: View {
    let item: ClipboardItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StructuredDataBadgeRow(item: item, compact: true)
            metaLine(item.isUniversalClipboardSource ? "From device" : "Application",
                     item.sourceAppName ?? "—")
            metaLine("Type", item.contentType.displayName)
            if let size = item.fileSize {
                metaLine("Size", ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
            }
            metaLine("First copy", item.effectiveFirstCopiedAt.formatted(date: .abbreviated, time: .shortened))
            metaLine("Last copy", item.effectiveLastCopiedAt.formatted(date: .abbreviated, time: .shortened))
            metaLine("Copies", "\(item.effectiveCopyCount)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func metaLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(.caption2.bold())
            Text(":")
            Text(value)
        }
    }
}

struct DuplicateCopyBadge: View {
    let item: ClipboardItem

    var body: some View {
        let today = item.copiesTodayCount()
        if item.effectiveCopyCount > 1 || today > 1 {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc.fill")
                if today > 1 {
                    Text("Copied \(today)× today")
                } else {
                    Text("Copied \(item.effectiveCopyCount)×")
                }
            }
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.15), in: Capsule())
            .foregroundStyle(.orange)
        }
    }
}
