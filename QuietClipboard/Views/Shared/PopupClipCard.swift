import SwiftUI

/// Compact grid cell for Quick Search and menu bar popover.
struct PopupClipCard: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let item: ClipboardItem
    let isSelected: Bool
    let onActivate: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    @AppStorage("QC.ClipPreviewStyle") private var styleRaw: String = ClipPreviewStyle.rich.rawValue

    private var clipPreviewStyle: ClipPreviewStyle {
        ClipPreviewStyle(rawValue: styleRaw) ?? .rich
    }

    var body: some View {
        Group {
            if clipPreviewStyle == .compact {
                compactBody
            } else {
                richBody
            }
        }
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

    private var richBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            ClipboardItemPreview(item: item)
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
