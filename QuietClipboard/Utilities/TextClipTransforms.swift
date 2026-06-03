import Foundation
import CryptoKit
import SwiftData

enum TextClipTransform: String, CaseIterable, Identifiable {
    case uppercase
    case lowercase
    case trim
    case base64Encode
    case base64Decode
    case urlEncode
    case urlDecode
    case jsonFormat
    case jsonMinify
    case slugify

    var id: String { rawValue }

    var title: String {
        switch self {
        case .uppercase: return "Uppercase"
        case .lowercase: return "Lowercase"
        case .trim: return "Trim whitespace"
        case .base64Encode: return "Base64 encode"
        case .base64Decode: return "Base64 decode"
        case .urlEncode: return "URL encode"
        case .urlDecode: return "URL decode"
        case .jsonFormat: return "Format JSON"
        case .jsonMinify: return "Minify JSON"
        case .slugify: return "Slugify"
        }
    }

    static func supports(_ item: ClipboardItem) -> Bool {
        guard item.resolvedText != nil else { return false }
        switch item.contentType {
        case .text, .code, .markdown, .link, .color, .svg, .richText:
            return true
        default:
            return false
        }
    }
}

enum TextClipTransforms {
    static func apply(_ transform: TextClipTransform, to text: String) -> String? {
        switch transform {
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .trim:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .base64Encode:
            return Data(text.utf8).base64EncodedString()
        case .base64Decode:
            guard let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let decoded = String(data: data, encoding: .utf8) else { return nil }
            return decoded
        case .urlEncode:
            return text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        case .urlDecode:
            return text.removingPercentEncoding ?? text
        case .jsonFormat:
            return formatJSON(text, pretty: true)
        case .jsonMinify:
            return formatJSON(text, pretty: false)
        case .slugify:
            return slugify(text)
        }
    }

    @MainActor
    static func apply(_ transform: TextClipTransform, to item: ClipboardItem, context: ModelContext) {
        guard let source = item.resolvedText,
              let result = apply(transform, to: source) else { return }
        item.textContent = result
        item.content = Data(result.utf8)
        item.contentHash = hash(result)
        item.fileSize = Int64(result.utf8.count)
        if item.title == nil || item.title == source || item.title == source.prefix(80).description {
            item.title = result.prefix(80).description
        }
        item.modifiedAt = .now
        item.applyStructuredDataDetection()
        try? context.save()
    }

    private static func formatJSON(_ text: String, pretty: Bool) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        var options: JSONSerialization.WritingOptions = []
        if pretty { options.insert(.prettyPrinted); options.insert(.sortedKeys) }
        guard let out = try? JSONSerialization.data(withJSONObject: object, options: options),
              let string = String(data: out, encoding: .utf8) else { return nil }
        return string
    }

    private static func slugify(_ text: String) -> String {
        let lowered = text.lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " "))
        let filtered = lowered.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        let collapsed = String(filtered)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: "-")
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private static func hash(_ text: String) -> String {
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension ClipboardItem {
    var resolvedText: String? {
        if let t = textContent, !t.isEmpty { return t }
        return String(data: content, encoding: .utf8)
    }
}
