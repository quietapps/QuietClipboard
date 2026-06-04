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
    @State private var isHovered: Bool = false

    private var clipPreviewStyle: ClipPreviewStyle {
        ClipPreviewStyle(rawValue: styleRaw) ?? .rich
    }

    private var isTextBased: Bool {
        switch item.contentType {
        case .text, .richText, .code, .other: return true
        default: return false
        }
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
        .frame(height: layout == .gridTile ? LibraryGridMetrics.popupTileHeight : nil)
        .frame(maxWidth: layout == .gridTile ? .infinity : nil)
        .clipped()
        .background(layout == .gridTile ? nil : cardBackground)
        .overlay(layout == .gridTile ? nil : cardStroke)
        .clipShape(RoundedRectangle(cornerRadius: layout == .gridTile ? 18 : 8))
        .overlay(
            layout == .gridTile
                ? RoundedRectangle(cornerRadius: 18).stroke(
                    isSelected ? Color.accentColor : (isHovered ? Color.white.opacity(0.3) : Color.clear),
                    lineWidth: isSelected ? 2 : 1
                )
                : nil
        )
        .contentShape(Rectangle())
        .onHover { hovered in
            if layout == .gridTile { isHovered = hovered }
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .onTapGesture {
            if coordinator.shouldProceedWithSensitiveAction(for: item) {
                onActivate()
            }
        }
        .pointerCursor()
        .contextMenu {
            PopupItemContextMenu(item: item)
        }
    }

    // MARK: - Grid tile (matches LibraryCard dark design)

    private var gridTileBody: some View {
        ZStack(alignment: .bottom) {
            (isTextBased ? Color(white: 0.13) : Color.black)

            if isTextBased {
                SensitiveContentGate(item: item, compact: true) {
                    Text(item.textContent ?? item.title ?? "")
                        .font(.system(
                            item.contentType == .code ? .caption : .callout,
                            design: item.contentType == .code ? .monospaced : .default
                        ))
                        .fontWeight(item.contentType == .code ? .regular : .semibold)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.top, 36)
                        .padding(.bottom, 26)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            } else {
                ClipboardItemPreview(item: item, compactRedaction: true, largeIcons: true, colorHexBottomInset: 54)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isTextBased {
                HStack(spacing: 4) {
                    ClipSourceIcon(item: item, size: 12)
                    Text(DateFormatting.relativeString(from: item.effectiveLastCopiedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black.opacity(0.6)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 48)
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 4) {
                        ClipSourceIcon(item: item, size: 12)
                        Text(DateFormatting.relativeString(from: item.effectiveLastCopiedAt))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }

            if isHovered {
                VStack {
                    HStack(alignment: .top) {
                        Image(systemName: item.contentType.systemImage)
                            .font(.callout)
                            .padding(7)
                            .background(Color.black.opacity(0.55), in: Circle())
                            .foregroundStyle(.white)

                        Spacer()

                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                                .font(.callout)
                                .padding(7)
                                .background(Color.black.opacity(0.55), in: Circle())
                                .foregroundStyle(.red.opacity(0.9))
                        }
                        .buttonStyle(.borderless)

                        Button(action: onToggleFavorite) {
                            Image(systemName: item.isFavorite ? "star.fill" : "star")
                                .font(.callout)
                                .padding(7)
                                .background(Color.black.opacity(0.55), in: Circle())
                                .foregroundStyle(item.isFavorite ? Color.yellow : .white)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(8)
                    Spacer()
                }
                .transition(.opacity)
            }

            if pinned.isPinned(item.id) || item.isSensitive && !coordinator.isSensitiveRevealed(item.id) || item.isFavorite {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            if pinned.isPinned(item.id) {
                                Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange)
                                    .padding(4).background(.thinMaterial, in: Circle())
                            }
                            if item.isSensitive, !coordinator.isSensitiveRevealed(item.id) {
                                Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.secondary)
                                    .padding(4).background(.thinMaterial, in: Circle())
                            }
                            if item.isFavorite {
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                                    .padding(4).background(.thinMaterial, in: Circle())
                            }
                        }
                        .padding(6)
                        .opacity(isHovered ? 0 : 1)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Flexible / compact layouts (unchanged)

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
