import SwiftUI
import SwiftData
import AppKit
import CryptoKit

struct ItemDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var monitor: ClipboardMonitor
    @Bindable var item: ClipboardItem

    @State private var editedText: String = ""
    @State private var isEditing: Bool = false
    @State private var showCopyHistory: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            CategorySuggestionBanner(item: item)
            if item.effectiveCopyCount > 1 {
                duplicateNotice
            }
            ScrollView {
                SensitiveContentGate(item: item) {
                    content
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            if showCopyHistory, item.effectiveCopyCount > 1 {
                copyHistorySection
                Divider()
            }
            ClipMetadataView(item: item)
                .padding(10)
        }
        .onAppear {
            editedText = item.textContent ?? ""
        }
        .onChange(of: item.id) { _, _ in
            editedText = item.textContent ?? ""
            isEditing = false
            showCopyHistory = false
            coordinator.concealSensitive(item.id)
        }
    }

    private var duplicateNotice: some View {
        HStack {
            DuplicateCopyBadge(item: item)
            Spacer()
            Button(showCopyHistory ? "Hide copies" : "Show copies") {
                showCopyHistory.toggle()
            }
            .font(.caption)
            .buttonStyle(.link)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var copyHistorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Copy history").font(.caption.bold())
            ForEach(item.sortedCopyEvents()) { event in
                HStack {
                    Text(event.copiedAt.formatted(date: .abbreviated, time: .shortened))
                    Text("·")
                    Text(event.sourceAppName ?? "Unknown")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: item.isSensitive && !coordinator.isSensitiveRevealed(item.id)
                  ? "lock.fill" : item.contentType.systemImage)
            SensitiveClipLabel(item: item, font: .headline, lineLimit: 1)
            Spacer()
            Button {
                if coordinator.shouldProceedWithSensitiveAction(for: item) {
                    ClipboardItemUsage.copyToPasteboard(item, context: context, monitor: monitor)
                }
            } label: {
                Label(
                    item.isSensitive && !coordinator.isSensitiveRevealed(item.id) ? "Reveal" : "Copy",
                    systemImage: item.isSensitive && !coordinator.isSensitiveRevealed(item.id)
                        ? "lock.open" : "doc.on.doc"
                )
            }
            .pointerCursor()
            Button {
                item.isFavorite.toggle()
                item.modifiedAt = .now
                try? context.save()
            } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(item.isFavorite ? .yellow : .secondary)
            }
            .pointerCursor()
            CategoryAssignmentMenu(item: item)
                .pointerCursor()
            PinnedSlotAssignmentMenu(item: item)
                .pointerCursor()
            exportMenu
            Button(role: .destructive) {
                coordinator.pinned.unpin(itemID: item.id)
                context.delete(item)
                try? context.save()
            } label: {
                Image(systemName: "trash")
            }
            .pointerCursor()
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        switch item.contentType {
        case .image, .screenshot:
            if let img = NSImage(data: item.content) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 600)
            }
            if let ocr = item.ocrText, !ocr.isEmpty {
                DisclosureGroup("OCR Text") {
                    Text(ocr).font(.callout).textSelection(.enabled)
                }
            }
        case .color:
            if let hex = item.colorHex, let color = Color(hex: hex) {
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color)
                        .frame(width: 200, height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                    Text(hex).font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        case .link:
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    LinkFaviconView(item: item, iconSize: 44)
                    VStack(alignment: .leading, spacing: 6) {
                        if let title = item.linkPreviewTitle {
                            Text(title).font(.title3.bold())
                        }
                        if let host = LinkPreviewService.displayHost(from: item.textContent) {
                            Text(host).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let desc = item.linkPreviewDescription, !desc.isEmpty {
                    Text(desc).foregroundStyle(.secondary)
                }
                if let data = item.linkPreviewImageData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 480, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                if let s = item.textContent, let url = URL(string: s) {
                    Link(s, destination: url).font(.callout)
                }
            }
        case .richText, .markdown:
            RichContentPreview(item: item)
        case .code:
            let lang = CodeHighlighter.detectLanguage(item.textContent ?? "")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(lang.displayName, systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                    Spacer()
                }
                Text(CodeHighlighter.attributedString(for: item.textContent ?? "", language: lang))
                    .textSelection(.enabled)
            }
        case .file:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "doc").font(.system(size: 48))
                if let s = item.textContent { Text(s).font(.callout) }
                if let size = item.fileSize {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        case .text:
            if RichContentRenderer.previewKind(for: item) == .markdown {
                RichContentPreview(item: item)
            } else if isEditing {
                textEditorBlock
            } else {
                plainTextBlock
            }
        default:
            if isEditing {
                textEditorBlock
            } else {
                plainTextBlock
            }
        }
    }

    private var exportMenu: some View {
        Menu {
            if RichContentRenderer.canExportMarkdown(item) {
                Button("Export as Markdown…") {
                    ClipExportService.presentSavePanel(for: item, format: .markdown)
                }
            }
            if RichContentRenderer.canExportRTF(item) {
                Button("Export as RTF…") {
                    ClipExportService.presentSavePanel(for: item, format: .rtf)
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
        .pointerCursor()
        .disabled(!RichContentRenderer.canExportMarkdown(item) && !RichContentRenderer.canExportRTF(item))
    }

    private var plainTextBlock: some View {
        Group {
            Text(item.textContent ?? "")
                .font(.system(.body, design: item.contentType == .code ? .monospaced : .default))
                .textSelection(.enabled)
            Button("Edit") { isEditing = true }
        }
    }

    @ViewBuilder
    private var textEditorBlock: some View {
        TextEditor(text: $editedText)
            .font(.system(.body, design: item.contentType == .code ? .monospaced : .default))
            .frame(minHeight: 200)
        HStack {
            Button("Save") {
                let data = Data(editedText.utf8)
                item.textContent = editedText
                item.content = data
                item.contentHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                item.normalizedFingerprint = DuplicateDetectionService.normalizedFingerprint(
                    text: editedText,
                    contentType: item.contentType,
                    contentHash: item.contentHash
                )
                item.modifiedAt = .now
                try? context.save()
                isEditing = false
            }
            Button("Cancel") {
                editedText = item.textContent ?? ""
                isEditing = false
            }
        }
    }
}
