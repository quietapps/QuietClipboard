import SwiftUI

/// List row for Quick Search and menu bar popover: activate on main area, delete on the right.
struct PopupClipRow: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject private var pinned = PinnedClipStore.shared
    let item: ClipboardItem
    let isSelected: Bool
    let onActivate: () -> Void
    let onTogglePin: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    @AppStorage("QC.ClipPreviewStyle") private var styleRaw: String = ClipPreviewStyle.rich.rawValue

    private var clipPreviewStyle: ClipPreviewStyle {
        ClipPreviewStyle(rawValue: styleRaw) ?? .rich
    }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                if coordinator.shouldProceedWithSensitiveAction(for: item) {
                    onActivate()
                }
            }) {
                HStack(spacing: 10) {
                    ClipRowLeadingAccessory(
                        item: item,
                        richSize: CGSize(
                            width: clipPreviewStyle == .compact ? 28 : 50,
                            height: clipPreviewStyle == .compact ? 28 : 50
                        )
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        SensitiveClipLabel(
                            item: item,
                            font: clipPreviewStyle == .compact ? .callout : .body,
                            lineLimit: clipPreviewStyle == .compact ? 2 : 1,
                            monospaced: item.contentType == .code
                        )
                        HStack(spacing: 6) {
                            StructuredDataBadgeRow(item: item, compact: true)
                            Image(systemName: item.contentType.systemImage).font(.caption2)
                            Text(item.contentType.displayName).font(.caption2)
                            Text("·").font(.caption2)
                            ClipSourceIcon(item: item, size: 10)
                            Text(item.sourceAppName ?? "Unknown").font(.caption2)
                            Text("·").font(.caption2)
                            Text(DateFormatting.relativeString(from: item.effectiveLastCopiedAt)).font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerCursor()

            Button(action: onTogglePin) {
                Image(systemName: pinned.isPinned(item.id) ? "pin.fill" : "pin")
                    .font(.body)
                    .foregroundStyle(pinned.isPinned(item.id) ? .orange : .secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .pointerCursor()
            .help(pinHelp)

            Button(action: onToggleFavorite) {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .font(.body)
                    .foregroundStyle(item.isFavorite ? .yellow : .secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .pointerCursor()
            .help(item.isFavorite ? "Remove from favorites" : "Add to favorites")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .pointerCursor()
            .help("Delete from history")
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, clipPreviewStyle == .compact ? 2 : 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        )
    }

    private var pinHelp: String {
        if let slot = pinned.slotIndex(for: item.id) {
            return "Unpin from slot \(slot + 1) (⌥P)"
        }
        return "Pin to slot (⌥P)"
    }
}
