import SwiftUI

/// Trailing copy-count badge, expand toggle, and per-copy timestamps (library list + grid).
struct CopyHistoryAccessory: View {
    let item: ClipboardItem
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        if item.effectiveCopyCount > 1 {
            VStack(alignment: .trailing, spacing: 4) {
                DuplicateCopyBadge(item: item)
                Button(action: onToggle) {
                    Text(isExpanded ? "Hide copies" : "Show \(item.effectiveCopyCount) copies")
                        .font(.caption2)
                        .multilineTextAlignment(.trailing)
                }
                .buttonStyle(.link)
                .pointerCursor()

                if isExpanded {
                    ForEach(item.sortedCopyEvents()) { event in
                        Text("\(event.copiedAt.formatted(date: .omitted, time: .shortened)) — \(event.sourceAppName ?? "Unknown")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
