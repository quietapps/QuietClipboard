import AppKit
import Foundation

struct ParsedMarkdownTable: Equatable {
    let headers: [String]
    let rows: [[String]]
}

enum RichContentRenderer {
    enum PreviewKind: Equatable {
        case rtf
        case markdown
        case plain
    }

    static func previewKind(for item: ClipboardItem) -> PreviewKind {
        switch item.contentType {
        case .richText: return .rtf
        case .other where item.fileMIMEType == PasteboardHelper.archiveMIME: return .plain
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
            return attributedStringFromStoredContent(item)
        case .markdown:
            guard let text = markdownPlainText(for: item) else { return nil }
            return markdownAttributedString(text)
        case .plain:
            return nil
        }
    }

    static func appearanceAdaptedPreview(for item: ClipboardItem) -> NSAttributedString? {
        guard let attr = attributedPreview(for: item) else { return nil }
        return appearanceAdapted(attr)
    }

    static func parsedMarkdownTable(for item: ClipboardItem) -> ParsedMarkdownTable? {
        guard previewKind(for: item) == .markdown,
              let text = markdownPlainText(for: item) else { return nil }
        return parseMarkdownTable(text)
    }

    static func appearanceAdapted(_ attr: NSAttributedString) -> NSAttributedString {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let mutable = NSMutableAttributedString(attributedString: attr)
        let fullRange = NSRange(location: 0, length: mutable.length)

        mutable.enumerateAttribute(.backgroundColor, in: fullRange) { value, range, _ in
            guard value != nil else { return }
            mutable.removeAttribute(.backgroundColor, range: range)
        }

        mutable.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            if let color = value as? NSColor, !colorNeedsReplacement(color, isDark: isDark) {
                return
            }
            mutable.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
        }

        mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
            guard let font = value as? NSFont, isHardToReadFont(font) else { return }
            let traits = font.fontDescriptor.symbolicTraits
            let isBold = traits.contains(.bold)
            let isItalic = traits.contains(.italic)
            let size = min(max(font.pointSize, 11), 15)
            var newFont = NSFont.systemFont(ofSize: size, weight: isBold ? .semibold : .regular)
            if isItalic {
                newFont = NSFontManager.shared.convert(newFont, toHaveTrait: .italicFontMask)
            }
            mutable.addAttribute(.font, value: newFont, range: range)
        }

        return mutable
    }

    static func parseMarkdownTable(_ markdown: String) -> ParsedMarkdownTable? {
        let lines = markdown
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return nil }

        for index in 0..<(lines.count - 1) {
            let headerLine = lines[index]
            let separatorLine = lines[index + 1]
            guard headerLine.contains("|"), separatorLine.contains("|"), separatorLine.contains("-") else {
                continue
            }

            let headers = parseMarkdownTableRow(headerLine)
            guard headers.count >= 2 else { continue }

            let separatorCells = parseMarkdownTableRow(separatorLine)
            guard separatorCells.count == headers.count,
                  separatorCells.allSatisfy(isMarkdownTableSeparatorCell) else {
                continue
            }

            var rows: [[String]] = []
            var rowIndex = index + 2
            while rowIndex < lines.count {
                let line = lines[rowIndex]
                guard line.contains("|") else { break }
                let row = parseMarkdownTableRow(line)
                guard !row.isEmpty else { break }
                rows.append(row)
                rowIndex += 1
            }

            guard !rows.isEmpty else { continue }
            return ParsedMarkdownTable(headers: headers, rows: rows)
        }

        return nil
    }

    static func markdownPlainText(for item: ClipboardItem) -> String? {
        if let text = item.textContent?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        if let s = String(data: item.content, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return s
        }
        if item.contentType == .richText || item.fileMIMEType == "text/html"
            || item.fileMIMEType == "text/rtf" || item.fileMIMEType == "application/rtfd",
           let attr = attributedStringFromStoredContent(item) {
            let plain = attr.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty { return plain }
        }
        return nil
    }

    static func rtfData(for item: ClipboardItem) -> Data? {
        if item.contentType == .richText, item.fileMIMEType == "text/rtf", !item.content.isEmpty {
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

    private static func attributedStringFromStoredContent(_ item: ClipboardItem) -> NSAttributedString? {
        guard !item.content.isEmpty else { return nil }
        switch item.fileMIMEType {
        case "text/html":
            return htmlAttributedString(from: item.content)
        case "application/rtfd":
            return rtfdAttributedString(from: item.content)
        default:
            return rtfAttributedString(from: item.content)
                ?? htmlAttributedString(from: item.content)
                ?? rtfdAttributedString(from: item.content)
        }
    }

    private static func rtfAttributedString(from data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }

    private static func rtfdAttributedString(from data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtfd],
            documentAttributes: nil
        )
    }

    private static func htmlAttributedString(from data: Data) -> NSAttributedString? {
        guard !data.isEmpty else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }

    private static func markdownAttributedString(_ markdown: String) -> NSAttributedString? {
        if let parsed = try? AttributedString(markdown: markdown, options: markdownOptions(.full)) {
            return NSAttributedString(parsed)
        }
        if let parsed = try? AttributedString(
            markdown: markdown,
            options: markdownOptions(.inlineOnlyPreservingWhitespace)
        ) {
            return NSAttributedString(parsed)
        }
        return NSAttributedString(string: markdown)
    }

    private static func markdownOptions(
        _ syntax: AttributedString.MarkdownParsingOptions.InterpretedSyntax
    ) -> AttributedString.MarkdownParsingOptions {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = syntax
        options.failurePolicy = .returnPartiallyParsedIfPossible
        return options
    }

    private static func parseMarkdownTableRow(_ line: String) -> [String] {
        var trimmed = line
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isMarkdownTableSeparatorCell(_ cell: String) -> Bool {
        guard !cell.isEmpty else { return false }
        return cell.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
    }

    private static func colorNeedsReplacement(_ color: NSColor, isDark: Bool) -> Bool {
        guard let resolved = color.usingColorSpace(.sRGB) else { return true }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        guard alpha > 0.05 else { return true }

        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return isDark ? luminance < 0.42 : luminance > 0.72
    }

    private static func isHardToReadFont(_ font: NSFont) -> Bool {
        let name = font.fontName.lowercased()
        let family = font.familyName?.lowercased() ?? name
        let serifMarkers = ["times", "georgia", "serif", "palatino", "garamond", "baskerville"]
        return serifMarkers.contains { name.contains($0) || family.contains($0) }
    }
}
