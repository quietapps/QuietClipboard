import Foundation

enum ContentTypeDetector {
    static func detect(_ snap: PasteboardSnapshot) -> ClipboardContentType {
        if !snap.fileURLs.isEmpty {
            return .file
        }
        if snap.png != nil || snap.tiff != nil {
            return .image
        }
        if let s = snap.string {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
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
        }
        if snap.rtf != nil || snap.rtfd != nil {
            return .richText
        }
        if snap.string != nil {
            return .text
        }
        return .other
    }

    static func isURL(_ s: String) -> Bool {
        guard s.count <= 2048, !s.contains(" "), !s.contains("\n") else { return false }
        guard s.lowercased().hasPrefix("http://") || s.lowercased().hasPrefix("https://") else {
            return false
        }
        return URL(string: s) != nil
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
        let signals = [
            "func ", "def ", "class ", "import ", "const ", "let ", "var ",
            "=>", "->", "public ", "private ", "fileprivate ", "fn ", "async ",
            "#include", "package ", "interface ", "struct ", "enum ",
            "return ", "println(", "console.log(", "printf("
        ]
        let lower = s
        var hits = 0
        for sig in signals where lower.contains(sig) { hits += 1 }
        let braceCount = lower.filter { $0 == "{" || $0 == "}" }.count
        let semicolons = lower.filter { $0 == ";" }.count
        return hits >= 1 || braceCount >= 2 || semicolons >= 3
    }

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
                let first = s.split(separator: "\n").first.map(String.init) ?? s
                return String(first.prefix(120))
            }
            return nil
        }
    }
}
