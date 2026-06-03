import SwiftUI

/// Compact grid cell for Quick Search and menu bar popover.
struct PopupClipCard: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject private var pinned = PinnedClipStore.shared
    let item: ClipboardItem
    let isSelected: Bool
    var layout: PopupCardLayout = .flexible
    let onActivate: () -> Void
    let onTogglePin: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    @AppStorage("QC.ClipPreviewStyle") private var styleRaw: String = ClipPreviewStyle.rich.rawValue

    private var clipPreviewStyle: ClipPreviewStyle {
        ClipPreviewStyle(rawValue: styleRaw) ?? .rich
    }

    var body: some View {
        Group {
            switch layout {
            case .gridTile:
                gridTileBody
            case .flexible:
                if clipPreviewStyle == .compact {
                    compactBody
                } else {
                    flexibleRichBody
                }
            }
        }
        .frame(height: layout == .gridTile ? LibraryGridMetrics.tileHeight : nil)
        .frame(maxWidth: layout == .gridTile ? .infinity : nil)
        .clipped()
        .background(cardBackground)
        .overlay(cardStroke)
        .contentShape(Rectangle())
        .onTapGesture {
            if coordinator.shouldProceedWithSensitiveAction(for: item) {
                onActivate()
            }
        }
        .pointerCursor()
    }

    private var gridTileBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ClipboardItemPreview(item: item, compactRedaction: true)
                    .frame(height: LibraryGridMetrics.previewHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()

                HStack(spacing: 4) {
                    if pinned.isPinned(item.id) {
                        badgeIcon("pin.fill", color: .orange)
                    }
                    if item.isSensitive, !coordinator.isSensitiveRevealed(item.id) {
                        badgeIcon("lock.fill", color: .secondary)
                    }
                    if item.isFavorite {
                        badgeIcon("star.fill", color: .yellow)
                    }
                    Image(systemName: item.contentType.systemImage)
                        .font(.caption2)
                        .padding(4)
                        .background(.thinMaterial, in: Circle())
                }
                .padding(6)
            }

            gridTileFooter
                .frame(height: LibraryGridMetrics.footerHeight, alignment: .top)
        }
        .frame(maxHeight: LibraryGridMetrics.tileHeight, alignment: .top)
    }

    private func badgeIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(4)
            .background(.thinMaterial, in: Circle())
    }

    private var gridTileFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            SensitiveClipLabel(item: item, font: .caption, lineLimit: 2, monospaced: item.contentType == .code)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                ClipSourceIcon(item: item, size: 10)
                Text(item.sourceAppName ?? "Unknown")
                    .font(.caption2)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(DateFormatting.relativeString(from: item.effectiveLastCopiedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(.secondary)

            actionRow
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var flexibleRichBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            ClipboardItemPreview(item: item, compactRedaction: true)
                .frame(height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            SensitiveClipLabel(item: item, font: .caption, lineLimit: 2)
                .frame(maxWidth: .infinity, alignment: .leading)

            actionRow
        }
        .padding(8)
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                ClipRowLeadingAccessory(item: item, richSize: CGSize(width: 28, height: 28))
                SensitiveClipLabel(item: item, font: .caption, lineLimit: 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 4) {
                StructuredDataBadgeRow(item: item, compact: true)
                Image(systemName: item.contentType.systemImage)
                    .font(.caption2)
                Text(item.contentType.displayName)
                    .font(.caption2)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            actionRow
        }
        .padding(8)
    }

    private var actionRow: some View {
        HStack(spacing: 2) {
            Spacer(minLength: 0)
            pinButton
            favoriteButton
            deleteButton
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.accentColor.opacity(0.25) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.15), lineWidth: 0.5)
    }

    private var pinButton: some View {
        Button(action: onTogglePin) {
            Image(systemName: pinned.isPinned(item.id) ? "pin.fill" : "pin")
                .font(.caption)
                .foregroundStyle(pinned.isPinned(item.id) ? .orange : .secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .pointerCursor()
        .help(pinHelp)
    }

    private var pinHelp: String {
        if let slot = pinned.slotIndex(for: item.id) {
            return "Unpin from slot \(slot + 1) (⌥P)"
        }
        return "Pin to slot (⌥P)"
    }

    private var favoriteButton: some View {
        Button(action: onToggleFavorite) {
            Image(systemName: item.isFavorite ? "star.fill" : "star")
                .font(.caption)
                .foregroundStyle(item.isFavorite ? .yellow : .secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .pointerCursor()
        .help(item.isFavorite ? "Remove from favorites" : "Add to favorites")
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .pointerCursor()
        .help("Delete from history")
    }
}

enum PopupCardLayout {
    case flexible
    case gridTile
}
