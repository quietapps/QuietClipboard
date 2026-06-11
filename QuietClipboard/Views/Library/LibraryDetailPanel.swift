import SwiftUI
import SwiftData

struct LibraryDetailPanel: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var monitor: ClipboardMonitor
    @Bindable var item: ClipboardItem

    let categoryName: String
    var onClose: () -> Void
    var onCopy: () -> Void

    private let panelBackground = Color(red: 0.08, green: 0.08, blue: 0.08)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                // Content type icon circle
                Image(systemName: item.contentType.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(8)
                    .background(Color.white.opacity(0.1), in: Circle())

                Text("∨ \(categoryName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                // Favorite button
                Button {
                    item.isFavorite.toggle()
                    item.modifiedAt = .now
                    try? context.save()
                } label: {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(item.isFavorite ? .yellow : .white.opacity(0.7))
                        .padding(7)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.borderless)
                .pointerCursor()

                // Delete button
                Button(role: .destructive) {
                    coordinator.pinned.unpin(itemID: item.id)
                    context.delete(item)
                    try? context.save()
                    onClose()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(7)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.borderless)
                .pointerCursor()

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(7)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(.borderless)
                .pointerCursor()
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .overlay(Color.white.opacity(0.08))

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Large content preview — images use .fit to show full image
                    ClipboardItemPreview(item: item, compactRedaction: false, largeIcons: true,
                                        fillImages: false, backgroundColor: panelBackground)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if isImageClip, !isRedacted {
                        Spacer().frame(height: 10)

                        Menu {
                            ImageActionsMenu(item: item)
                        } label: {
                            Label("Image Actions", systemImage: "wand.and.stars")
                                .font(.callout)
                                .foregroundStyle(.white)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .pointerCursor()

                        if let ocr = item.ocrText, !ocr.isEmpty {
                            Spacer().frame(height: 10)
                            ocrSection(ocr)
                        }
                    }

                    Spacer().frame(height: 10)

                    // CREATED
                    metaField(
                        label: "CREATED",
                        content: {
                            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.callout)
                                .foregroundStyle(.white)
                        }
                    )

                    Spacer().frame(height: 10)

                    // SOURCE
                    metaField(label: "SOURCE") {
                        HStack(spacing: 6) {
                            ClipSourceIcon(item: item, size: 16)
                            Text(item.sourceAppName ?? "Unknown")
                                .font(.callout)
                                .foregroundStyle(.white)
                        }
                    }

                    Spacer().frame(height: 10)

                    // LINK (if applicable)
                    if item.contentType == .link, let urlString = item.textContent {
                        metaField(label: "LINK") {
                            HStack(spacing: 4) {
                                Text(urlString)
                                    .font(.callout)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if let url = URL(string: urlString) {
                                    Link(destination: url) {
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }

                        Spacer().frame(height: 10)
                    }

                    // COPIES (only when copied more than once)
                    if item.effectiveCopyCount > 1 {
                        metaField(
                            label: "COPIES",
                            content: {
                                Text("\(item.effectiveCopyCount) times")
                                    .font(.callout)
                                    .foregroundStyle(.white)
                            }
                        )

                        Spacer().frame(height: 10)

                        metaField(
                            label: "LAST COPIED",
                            content: {
                                Text(item.effectiveLastCopiedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.callout)
                                    .foregroundStyle(.white)
                            }
                        )

                        Spacer().frame(height: 10)
                    }

                    // SIZE (if available)
                    if let size = item.fileSize {
                        metaField(
                            label: "SIZE",
                            content: {
                                Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                    .font(.callout)
                                    .foregroundStyle(.white)
                            }
                        )
                        Spacer().frame(height: 10)
                    }
                }
                .padding(16)
            }

            // Bottom pinned "Copy to clipboard" button
            Button(action: onCopy) {
                Label("Copy to clipboard", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .background(panelBackground)
        .clipShape(
            .rect(
                topLeadingRadius: 14,
                bottomLeadingRadius: 14,
                bottomTrailingRadius: 0,
                topTrailingRadius: 0
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                .padding(.trailing, -14)
        )
    }

    private var isImageClip: Bool {
        item.contentType == .image || item.contentType == .screenshot
    }

    private var isRedacted: Bool {
        item.isSensitive && !coordinator.isSensitiveRevealed(item.id)
    }

    /// Recognized text, rendered monospaced so the layout-preserved columns/indentation line
    /// up, with copy actions for the exact and whitespace-cleaned forms.
    private func ocrSection(_ ocr: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TEXT IN IMAGE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            ScrollView([.horizontal, .vertical]) {
                Text(ocr)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 160)
            .padding(8)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 8) {
                Button {
                    coordinator.copyOCRText(item, cleaned: false)
                } label: {
                    Label("Copy Exact", systemImage: "text.alignleft")
                }
                .pointerCursor()
                Button {
                    coordinator.copyOCRText(item, cleaned: true)
                } label: {
                    Label("Copy Cleaned", systemImage: "text.badge.checkmark")
                }
                .pointerCursor()
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func metaField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .frame(width: 90, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
    }
}
