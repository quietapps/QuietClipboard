import SwiftUI
import AppKit

enum ClipboardCardLayout {
    case flexible
    case gridTile
}

struct ClipboardItemCard: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject private var pinned = PinnedClipStore.shared
    let item: ClipboardItem
    let isSelected: Bool
    var layout: ClipboardCardLayout = .flexible
    var isCopyHistoryExpanded: Bool = false
    var onToggleCopyHistory: (() -> Void)?

    @AppStorage("QC.ClipPreviewStyle") private var styleRaw: String = ClipPreviewStyle.rich.rawValue

    private var clipPreviewStyle: ClipPreviewStyle {
        ClipPreviewStyle(rawValue: styleRaw) ?? .rich
    }

    var body: some View {
        Group {
            if clipPreviewStyle == .compact && layout != .gridTile {
                compactBody
            } else {
                richBody
            }
        }
        .frame(height: layout == .gridTile ? LibraryGridMetrics.tileHeight : nil)
        .frame(maxWidth: layout == .gridTile ? .infinity : nil)
        .clipped()
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

    private var richBody: some View {
        VStack(alignment: .leading, spacing: layout == .gridTile ? 0 : 6) {
            ZStack(alignment: .topTrailing) {
                ClipboardItemPreview(item: item, compactRedaction: true)
                    .frame(height: layout == .gridTile ? LibraryGridMetrics.previewHeight : 120)
                    .frame(maxWidth: .infinity)
                    .clipped()

                HStack(spacing: 4) {
                    if pinned.isPinned(item.id) {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(4)
                            .background(.thinMaterial, in: Circle())
                    }
                    if item.isSensitive && !coordinator.isSensitiveRevealed(item.id) {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(4)
                            .background(.thinMaterial, in: Circle())
                    }
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

            cardFooter
                .frame(height: layout == .gridTile ? LibraryGridMetrics.footerHeight : nil, alignment: .top)
        }
        .frame(maxHeight: layout == .gridTile ? LibraryGridMetrics.tileHeight : nil, alignment: .top)
    }

    private var compactBody: some View {
        HStack(alignment: .top, spacing: 10) {
            ClipRowLeadingAccessory(item: item, richSize: CGSize(width: 36, height: 36))
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    SensitiveClipLabel(item: item, font: .callout, lineLimit: 2, monospaced: item.contentType == .code)
                    Spacer(minLength: 4)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                cardFooter
            }
        }
        .padding(10)
    }

    private var cardFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            if clipPreviewStyle == .rich || layout == .gridTile {
                SensitiveClipLabel(
                    item: item,
                    font: layout == .gridTile ? .caption : .callout,
                    lineLimit: 2,
                    monospaced: item.contentType == .code
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .center, spacing: 6) {
                StructuredDataBadgeRow(item: item, compact: true)
                ClipSourceIcon(item: item, size: 12)
                Text(item.sourceAppName ?? "Unknown")
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                Text(DateFormatting.relativeString(from: item.effectiveLastCopiedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            if layout == .gridTile, item.effectiveCopyCount > 1 {
                DuplicateCopyBadge(item: item)
            } else if let onToggleCopyHistory {
                CopyHistoryAccessory(
                    item: item,
                    isExpanded: isCopyHistoryExpanded,
                    onToggle: onToggleCopyHistory
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, layout == .gridTile || clipPreviewStyle == .rich ? 8 : 0)
        .padding(.vertical, layout == .gridTile ? 6 : 0)
        .padding(.bottom, layout == .gridTile ? 0 : (clipPreviewStyle == .compact ? 0 : 8))
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private var typeBadge: some View {
        Image(systemName: item.contentType.systemImage)
            .font(.caption2)
            .padding(4)
            .background(.thinMaterial, in: Circle())
    }

}

struct ClipboardItemRow: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject private var pinned = PinnedClipStore.shared
    let item: ClipboardItem
    let isSelected: Bool
    var isCopyHistoryExpanded: Bool = false
    var onToggleCopyHistory: (() -> Void)?

    @AppStorage("QC.ClipPreviewStyle") private var styleRaw: String = ClipPreviewStyle.rich.rawValue

    private var clipPreviewStyle: ClipPreviewStyle {
        ClipPreviewStyle(rawValue: styleRaw) ?? .rich
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ClipRowLeadingAccessory(
                item: item,
                richSize: CGSize(
                    width: clipPreviewStyle == .compact ? 32 : 56,
                    height: clipPreviewStyle == .compact ? 32 : 56
                )
            )
            VStack(alignment: .leading, spacing: 2) {
                SensitiveClipLabel(item: item, font: .body, lineLimit: 1, monospaced: item.contentType == .code)
                HStack(spacing: 6) {
                    StructuredDataBadgeRow(item: item, compact: true)
                    Image(systemName: item.contentType.systemImage).font(.caption2)
                    Text(item.contentType.displayName).font(.caption2)
                    Text("·").font(.caption2)
                    Text(item.sourceAppName ?? "Unknown").font(.caption2)
                    Text("·").font(.caption2)
                    Text(DateFormatting.relativeString(from: item.effectiveLastCopiedAt)).font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let onToggleCopyHistory {
                CopyHistoryAccessory(
                    item: item,
                    isExpanded: isCopyHistoryExpanded,
                    onToggle: onToggleCopyHistory
                )
            }
            HStack(spacing: 4) {
                if pinned.isPinned(item.id) {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if item.isFavorite {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, clipPreviewStyle == .compact ? 4 : 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
    }
}
