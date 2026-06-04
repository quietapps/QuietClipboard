import Foundation

enum ContentTypeDetector {
    static func detect(_ snap: PasteboardSnapshot) -> ClipboardContentType {
        if !snap.fileURLs.isEmpty {
            return .file
        }
        if snap.png != nil || snap.tiff != nil {
            return .image
        }
        if snap.rtf != nil || snap.rtfd != nil {
            return .richText
        }
        if let html = snap.html,
           !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .richText
        }
        if let s = snap.string {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return !snap.types.isEmpty ? .other : .text
            }
            if trimmed.lowercased().hasPrefix("<svg") || trimmed.contains("<svg ") {
                return .svg
            }
            if ColorParsing.isColorString(trimmed) {
                return .color
            }
            if isURL(trimmed) {
                return .link
            }
            if looksLikeMarkdown(trimmed) {
                return .markdown
            }
            if looksLikeCode(trimmed) {
                return .code
            }
            return .text
        }
        if !snap.types.isEmpty {
            return .other
        }
        return .other
    }

    static func isURL(_ s: String) -> Bool {
        guard s.count <= 2048, !s.contains(" "), !s.contains("\n") else { return false }
        let lower = s.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://")
            || lower.hasPrefix("mailto:") || lower.hasPrefix("ftp://") || lower.hasPrefix("ftps://") {
            return URL(string: s) != nil
        }
        // Bare domain like `www.example.com/path` — treat as a link.
        if lower.hasPrefix("www."), s.contains(".") {
            return URL(string: "https://" + s) != nil
        }
        return false
    }

    static func looksLikeMarkdown(_ s: String) -> Bool {
        guard s.count >= 12, s.count <= 500_000 else { return false }
        var score = 0
        if s.contains("```") { score += 2 }
        if s.contains("\n# ") || s.hasPrefix("# ") { score += 2 }
        if s.contains("**") || s.contains("__") { score += 1 }
        if s.contains("](") && (s.contains("http://") || s.contains("https://")) { score += 2 }
        let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.contains(where: { line in
            line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("> ")
                || line.hasPrefix("1. ")
        }) {
            score += 1
        }
        if s.contains("\n|") && s.filter({ $0 == "|" }).count >= 4 { score += 1 }
        return score >= 2
    }

    static func looksLikeCode(_ s: String) -> Bool {
        guard s.count <= 100_000 else { return false }
        // Cheap O(n) structural counts over the whole string.
        let braceCount = s.reduce(0) { $1 == "{" || $1 == "}" ? $0 + 1 : $0 }
        let semicolons = s.reduce(0) { $1 == ";" ? $0 + 1 : $0 }
        let parenCount = s.reduce(0) { $1 == "(" || $1 == ")" ? $0 + 1 : $0 }

        // Keyword/operator patterns that rarely occur in ordinary prose. Word boundaries and a
        // required assignment/call shape keep sentences like "Please let me import the file" out.
        let head = s.count > 8000 ? String(s.prefix(8000)) : s
        var strongHits = 0
        for p in Self.codeSignalPatterns where head.range(of: p, options: .regularExpression) != nil {
            strongHits += 1
            if strongHits >= 2 { break }
        }

        if braceCount >= 4 && parenCount >= 2 { return true }
        if strongHits >= 2 { return true }
        if strongHits >= 1 && (braceCount >= 2 || semicolons >= 2) { return true }
        return false
    }

    private static let codeSignalPatterns: [String] = [
        #"\bfunc\s+\w"#, #"\bdef\s+\w+\s*\("#, #"=>"#, #"->"#, #"#include"#, #"#import"#,
        #"\bconsole\.log\("#, #"\bprintf\("#, #"\bprintln!?\("#, #"System\.out"#,
        #"\bpublic\s+(class|func|static|void|final)"#, #"\b(const|let|var)\s+\w+\s*[:=]"#,
        #"==="#, #"!=="#, #":="#, #"</\w+>"#, #"\}\s*else\s*\{"#, #"\bself\.\w"#,
        #"\bfunction\s+\w"#, #"\breturn\s+\w.*;"#
    ]

    static func title(for snap: PasteboardSnapshot, type: ClipboardContentType) -> String? {
        switch type {
        case .file:
            return snap.fileURLs.first?.lastPathComponent
        case .image, .screenshot:
            return "Image"
        case .color:
            return snap.string?.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            if let s = snap.string {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let first = trimmed.split(separator: "\n").first.map(String.init) ?? trimmed
                    return String(first.prefix(120))
                }
            }
            if let html = snap.html?.trimmingCharacters(in: .whitespacesAndNewlines), !html.isEmpty {
                return String(html.prefix(120))
            }
            return nil
        }
    }
}
