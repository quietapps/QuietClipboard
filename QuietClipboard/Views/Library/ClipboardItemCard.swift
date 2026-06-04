import SwiftUI
import AppKit
import UniformTypeIdentifiers

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

// MARK: - LibraryCard (new grid tile for redesigned Library)

struct LibraryCard: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var coordinator: AppCoordinator

    let item: ClipboardItem
    let isSelected: Bool
    var isQueued: Bool = false
    var queuePosition: Int? = nil
    var onTap: () -> Void
    var onCopy: () -> Void
    var onFavorite: () -> Void
    var onDelete: () -> Void

    @State private var isHovered: Bool = false
    @State private var isDragging: Bool = false

    private var isTextBased: Bool {
        switch item.contentType {
        case .text, .richText, .code, .other: return true
        default: return false
        }
    }

    private var queueStrokeColor: Color {
        if isSelected { return Color.accentColor }
        if isQueued { return Color(red: 0.2, green: 0.72, blue: 0.45) }
        if isHovered && !isDragging { return Color.white.opacity(0.3) }
        return .clear
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background: subtle grey for text tiles, black for media
            (isTextBased ? Color(white: 0.13) : Color.black)

            // Content fill — dim when being dragged
            if isTextBased {
                // Top padding (44) clears hover button area; bottom padding (34) clears footer
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
                        .padding(.top, 44)
                        .padding(.bottom, 34)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .opacity(isDragging ? 0.4 : 1)
            } else {
                ClipboardItemPreview(item: item, compactRedaction: true, largeIcons: true, colorHexBottomInset: 54)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(isDragging ? 0.4 : 1)
            }

            // Footer: gradient for media tiles, plain row for text tiles
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
                        if let size = item.fileSize {
                            Text("·").font(.caption2).foregroundStyle(.white.opacity(0.5))
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }

            if isQueued, let queuePosition {
                VStack {
                    HStack {
                        Text("\(queuePosition)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Color(red: 0.2, green: 0.72, blue: 0.45), in: Circle())
                            .padding(8)
                        Spacer()
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }

            // Hover action buttons
            if isHovered {
                VStack {
                    HStack(alignment: .top) {
                        // Type icon button (left)
                        Button {
                            // no-op; informational / future use for type filter
                        } label: {
                            Image(systemName: item.contentType.systemImage)
                                .font(.callout)
                                .padding(7)
                                .background(Color.black.opacity(0.55), in: Circle())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        // Delete button
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Image(systemName: "trash")
                                .font(.callout)
                                .padding(7)
                                .background(Color.black.opacity(0.55), in: Circle())
                                .foregroundStyle(.red.opacity(0.9))
                        }
                        .buttonStyle(.borderless)

                        // Favorite button
                        Button {
                            onFavorite()
                        } label: {
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
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    queueStrokeColor,
                    lineWidth: isSelected || isQueued ? 2 : 1
                )
        )
        .overlay(
            isDragging ?
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(Color.white.opacity(0.6))
            : nil
        )
        .contentShape(Rectangle())
        .onHover { hovered in
            isHovered = hovered
            if !hovered { isDragging = false }
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .animation(.easeInOut(duration: 0.1), value: isDragging)
        .highPriorityGesture(TapGesture().onEnded { onTap() })
        .simultaneousGesture(TapGesture(count: 2).onEnded { onCopy() })
        .onDrag {
            DispatchQueue.main.async { isDragging = true }
            let provider = NSItemProvider()
            let idString = item.id.uuidString
            // Register custom UTI for internal drops
            if let data = idString.data(using: .utf8) {
                provider.registerDataRepresentation(
                    forTypeIdentifier: "app.quiet.QuietClipboard.item-id",
                    visibility: .all
                ) { completion in
                    completion(data, nil)
                    return nil
                }
            }
            // Register content-specific public type
            switch item.contentType {
            case .image, .screenshot:
                if let imgData = item.thumbnailData ?? (item.content as Data?),
                   let nsImage = NSImage(data: imgData) {
                    provider.registerObject(nsImage, visibility: .all)
                }
            case .text, .code, .richText:
                if let text = item.textContent ?? item.title {
                    provider.registerObject(text as NSString, visibility: .all)
                }
            case .link:
                if let urlString = item.textContent, let url = URL(string: urlString) {
                    provider.registerObject(url as NSURL, visibility: .all)
                }
            default:
                if let text = item.textContent ?? item.title {
                    provider.registerObject(text as NSString, visibility: .all)
                }
            }
            return provider
        } preview: {
            ClipboardItemPreview(item: item, compactRedaction: true, largeIcons: false)
                .frame(width: 80, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .opacity(0.55)
                .allowsHitTesting(false)
        }
        .contextMenu { ItemContextMenu(item: item) }
        .pointerCursor()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.contentType.displayName) clip from \(item.sourceAppName ?? "unknown app")")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: -

struct ClipboardItemRow: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject private var pinned = PinnedClipStore.shared
    let item: ClipboardItem
    let isSelected: Bool
    var isQueued: Bool = false
    var queuePosition: Int? = nil
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
                .fill(rowBackground)
        )
        .overlay(alignment: .leading) {
            if isQueued, let queuePosition {
                Text("\(queuePosition)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(Color(red: 0.2, green: 0.72, blue: 0.45), in: Circle())
                    .offset(x: -4)
            }
        }
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.15) }
        if isQueued { return Color(red: 0.2, green: 0.72, blue: 0.45).opacity(0.12) }
        return .clear
    }
}
