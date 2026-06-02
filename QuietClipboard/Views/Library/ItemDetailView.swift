import SwiftUI
import SwiftData
import AppKit
import CryptoKit

struct ItemDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var item: ClipboardItem

    @State private var editedText: String = ""
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                content
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            metadata
        }
        .onAppear {
            editedText = item.textContent ?? ""
        }
        .onChange(of: item.id) { _, _ in
            editedText = item.textContent ?? ""
            isEditing = false
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: item.contentType.systemImage)
            Text(item.title ?? item.contentType.displayName)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button {
                PasteboardHelper.write(item, to: .general)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
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
            Button(role: .destructive) {
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
            VStack(alignment: .leading, spacing: 8) {
                if let data = item.linkPreviewImageData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 480)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if let title = item.linkPreviewTitle {
                    Text(title).font(.title3.bold())
                }
                if let desc = item.linkPreviewDescription {
                    Text(desc).foregroundStyle(.secondary)
                }
                if let s = item.textContent, let url = URL(string: s) {
                    Link(s, destination: url).font(.callout)
                }
            }
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
        default:
            if isEditing {
                TextEditor(text: $editedText)
                    .font(.system(.body, design: item.contentType == .code ? .monospaced : .default))
                    .frame(minHeight: 200)
                HStack {
                    Button("Save") {
                        let data = Data(editedText.utf8)
                        item.textContent = editedText
                        item.content = data
                        item.contentHash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                        item.modifiedAt = .now
                        try? context.save()
                        isEditing = false
                    }
                    Button("Cancel") {
                        editedText = item.textContent ?? ""
                        isEditing = false
                    }
                }
            } else {
                Text(item.textContent ?? "")
                    .font(.system(.body, design: item.contentType == .code ? .monospaced : .default))
                    .textSelection(.enabled)
                Button("Edit") { isEditing = true }
            }
        }
    }

    private var metadata: some View {
        HStack(spacing: 16) {
            metaItem("App", item.sourceAppName ?? "—")
            metaItem("Type", item.contentType.displayName)
            if let size = item.fileSize {
                metaItem("Size", ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
            }
            metaItem("Copied", item.createdAt.formatted(date: .abbreviated, time: .shortened))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(10)
    }

    private func metaItem(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading) {
            Text(k).font(.caption2.bold())
            Text(v)
        }
    }
}
