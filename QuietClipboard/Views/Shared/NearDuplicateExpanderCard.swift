import SwiftUI

/// Grid/list control for collapsed near-duplicate siblings with its own preview thumbnail.
struct NearDuplicateExpanderCard: View {
    let siblings: [ClipboardItem]
    let groupKey: String
    @Binding var expandedGroups: Set<String>
    var gridStyle: Bool = true

    private var isExpanded: Bool { expandedGroups.contains(groupKey) }

    private var previewItem: ClipboardItem? { siblings.first }

    var body: some View {
        Button(action: toggle) {
            if gridStyle {
                gridBody
            } else {
                listBody
            }
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .accessibilityLabel(isExpanded ? "Hide similar clips" : "Show \(siblings.count) similar clips")
    }

    private var gridBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                previewArea
                    .frame(height: LibraryGridMetrics.previewHeight)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                if siblings.count > 1 {
                    Text("+\(siblings.count - 1)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(6)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                Text(isExpanded ? "Hide \(siblings.count) similar" : "Show \(siblings.count) similar")
                    .font(.caption)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.accentColor)
            .frame(height: LibraryGridMetrics.footerHeight)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
        .clipped()
    }

    private var listBody: some View {
        HStack(spacing: 10) {
            previewArea
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(isExpanded ? "Hide similar" : "Show \(siblings.count) similar")
                    .font(.caption.weight(.medium))
                if let item = previewItem {
                    Text(item.title ?? item.textContent ?? item.contentType.displayName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var previewArea: some View {
        if let item = previewItem {
            ClipboardItemPreview(item: item)
        } else {
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                Image(systemName: "doc.on.doc")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggle() {
        if isExpanded {
            expandedGroups.remove(groupKey)
        } else {
            expandedGroups.insert(groupKey)
        }
    }
}
