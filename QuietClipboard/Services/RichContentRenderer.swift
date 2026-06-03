import AppKit
import Foundation

enum RichContentRenderer {
    enum PreviewKind: Equatable {
        case rtf
        case markdown
        case plain
    }

    static func previewKind(for item: ClipboardItem) -> PreviewKind {
        switch item.contentType {
        case .richText: return .rtf
        case .markdown: return .markdown
        case .text, .other:
            if let text = item.textContent, ContentTypeDetector.looksLikeMarkdown(text) {
                return .markdown
            }
            return .plain
        default:
            if let text = item.textContent, ContentTypeDetector.looksLikeMarkdown(text) {
                return .markdown
            }
            return .plain
        }
    }

    static func canExportMarkdown(_ item: ClipboardItem) -> Bool {
        switch previewKind(for: item) {
        case .markdown, .plain:
            return markdownPlainText(for: item) != nil
        case .rtf:
            return markdownPlainText(for: item) != nil
        }
    }

    static func canExportRTF(_ item: ClipboardItem) -> Bool {
        rtfData(for: item) != nil
    }

    static func attributedPreview(for item: ClipboardItem) -> NSAttributedString? {
        switch previewKind(for: item) {
        case .rtf:
            return rtfAttributedString(from: item.content)
        case .markdown:
            guard let text = markdownPlainText(for: item) else { return nil }
            return markdownAttributedString(text)
        case .plain:
            return nil
        }
    }

    static func markdownPlainText(for item: ClipboardItem) -> String? {
        if let text = item.textContent?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        if let s = String(data: item.content, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return s
        }
        if item.contentType == .richText,
           let attr = rtfAttributedString(from: item.content) {
            return attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    static func rtfData(for item: ClipboardItem) -> Data? {
        if item.contentType == .richText, !item.content.isEmpty {
            return item.content
        }
        guard let text = markdownPlainText(for: item) else { return nil }
        let attr = NSAttributedString(string: text)
        let range = NSRange(location: 0, length: attr.length)
        return try? attr.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    static func markdownData(for item: ClipboardItem) -> Data? {
        guard let text = markdownPlainText(for: item) else { return nil }
        return Data(text.utf8)
    }

    private static func rtfAttributedString(from data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }

    private static func markdownAttributedString(_ markdown: String) -> NSAttributedString? {
        var full = AttributedString.MarkdownParsingOptions()
        full.interpretedSyntax = .full
        if let parsed = try? AttributedString(markdown: markdown, options: full) {
            return NSAttributedString(parsed)
        }
        var inline = AttributedString.MarkdownParsingOptions()
        inline.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let parsed = try? AttributedString(markdown: markdown, options: inline) {
            return NSAttributedString(parsed)
        }
        return NSAttributedString(string: markdown)
    }
}
