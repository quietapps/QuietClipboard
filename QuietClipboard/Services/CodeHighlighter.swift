import AppKit
import SwiftUI

enum CodeLanguage: String, CaseIterable {
    case swift, python, javascript, typescript, json, html, css, shell, sql, go, rust, ruby, java, kotlin, c, cpp, csharp, unknown

    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .json: return "JSON"
        case .html: return "HTML"
        case .css: return "CSS"
        case .shell: return "Shell"
        case .sql: return "SQL"
        case .go: return "Go"
        case .rust: return "Rust"
        case .ruby: return "Ruby"
        case .java: return "Java"
        case .kotlin: return "Kotlin"
        case .c: return "C"
        case .cpp: return "C++"
        case .csharp: return "C#"
        case .unknown: return "Code"
        }
    }
}

enum CodeHighlighter {
    static func detectLanguage(_ source: String) -> CodeLanguage {
        let s = source
        if s.contains("func ") && s.contains("->") && s.contains("let ") { return .swift }
        if s.contains("def ") && s.contains(":\n") { return .python }
        if s.contains("interface ") || s.contains(": string") || s.contains(": number") { return .typescript }
        if s.contains("=>") || s.contains("console.log") || s.contains("const ") { return .javascript }
        if s.hasPrefix("{") && s.contains("\":") { return .json }
        if s.contains("<!DOCTYPE") || s.contains("<html") { return .html }
        if s.contains("{") && s.contains(";") && (s.contains("background:") || s.contains("color:")) { return .css }
        if s.hasPrefix("#!") || s.contains("$(") { return .shell }
        if s.range(of: #"(?i)^\s*(SELECT|INSERT|UPDATE|DELETE)\s"#, options: .regularExpression) != nil { return .sql }
        if s.contains("package main") || s.contains("fmt.Print") { return .go }
        if s.contains("fn ") && s.contains("->") { return .rust }
        if s.contains("def ") && s.contains("end") { return .ruby }
        if s.contains("public class ") || s.contains("System.out.println") { return .java }
        if s.contains("fun ") && s.contains("val ") { return .kotlin }
        if s.contains("#include") && s.contains("std::") { return .cpp }
        if s.contains("#include") { return .c }
        if s.contains("using System") || s.contains("Console.WriteLine") { return .csharp }
        return .unknown
    }

    static let keywordsByLang: [CodeLanguage: [String]] = [
        .swift: ["let", "var", "func", "class", "struct", "enum", "if", "else", "guard", "return", "import", "for", "while", "switch", "case", "self", "throws", "throw", "try", "as", "is", "in", "extension", "protocol", "public", "private", "fileprivate", "internal", "static", "async", "await"],
        .python: ["def", "class", "if", "elif", "else", "return", "import", "from", "for", "while", "try", "except", "finally", "with", "as", "in", "lambda", "yield", "True", "False", "None", "self"],
        .javascript: ["var", "let", "const", "function", "return", "if", "else", "for", "while", "switch", "case", "class", "extends", "new", "this", "import", "export", "from", "default", "async", "await", "true", "false", "null", "undefined"],
        .typescript: ["var", "let", "const", "function", "return", "if", "else", "for", "while", "switch", "case", "class", "extends", "new", "this", "import", "export", "from", "default", "async", "await", "true", "false", "null", "undefined", "interface", "type", "enum"],
        .go: ["func", "package", "import", "var", "const", "type", "struct", "interface", "if", "else", "for", "range", "return", "go", "defer", "chan", "select", "switch", "case", "default", "nil", "true", "false"],
        .rust: ["fn", "let", "mut", "const", "struct", "enum", "impl", "trait", "use", "pub", "mod", "if", "else", "match", "for", "while", "loop", "return", "self", "Self", "ref", "as"],
        .json: [],
        .css: [],
        .html: [],
        .shell: ["if", "then", "else", "fi", "for", "do", "done", "while", "case", "esac", "function", "return", "export", "echo"],
        .sql: ["SELECT", "FROM", "WHERE", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "GROUP", "BY", "ORDER", "LIMIT", "INSERT", "UPDATE", "DELETE", "SET", "VALUES", "INTO", "CREATE", "TABLE", "DROP", "ALTER", "AS", "AND", "OR", "NOT", "NULL"],
        .ruby: ["def", "class", "module", "end", "if", "elsif", "else", "unless", "while", "until", "do", "for", "in", "return", "yield", "true", "false", "nil", "self"],
        .java: ["public", "private", "protected", "class", "interface", "extends", "implements", "static", "final", "void", "int", "long", "double", "float", "boolean", "String", "new", "return", "if", "else", "for", "while", "switch", "case", "this", "super", "null", "true", "false"],
        .kotlin: ["fun", "val", "var", "class", "object", "interface", "if", "else", "when", "for", "while", "return", "this", "super", "null", "true", "false", "import", "package"],
        .c: ["int", "char", "long", "short", "void", "if", "else", "for", "while", "do", "switch", "case", "return", "struct", "typedef", "static", "extern", "const", "sizeof"],
        .cpp: ["int", "char", "void", "if", "else", "for", "while", "return", "class", "struct", "public", "private", "protected", "namespace", "using", "template", "typename", "const", "auto", "new", "delete"],
        .csharp: ["public", "private", "protected", "internal", "class", "interface", "struct", "void", "int", "string", "var", "new", "return", "if", "else", "for", "while", "switch", "case", "using", "namespace", "true", "false", "null", "this"],
    ]

    static func attributedString(for source: String, language: CodeLanguage) -> AttributedString {
        let baseFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        var attr = AttributedString(source)
        attr.font = .system(.body, design: .monospaced)
        let keywords = keywordsByLang[language] ?? []

        var ns = NSMutableAttributedString(string: source, attributes: [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor
        ])

        for kw in keywords {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: kw) + "\\b"
            apply(pattern: pattern, options: [], color: .systemPurple, to: ns)
        }

        apply(pattern: "\"[^\"\\n]*\"", options: [], color: .systemRed, to: ns)
        apply(pattern: "'[^'\\n]*'", options: [], color: .systemRed, to: ns)
        apply(pattern: "//[^\\n]*", options: [], color: .secondaryLabelColor, to: ns)
        apply(pattern: "#[^\\n]*", options: [], color: .secondaryLabelColor, to: ns)
        apply(pattern: "\\b\\d+(\\.\\d+)?\\b", options: [], color: .systemOrange, to: ns)

        return AttributedString(ns)
    }

    private static func apply(pattern: String, options: NSRegularExpression.Options, color: NSColor, to ns: NSMutableAttributedString) {
        guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let range = NSRange(location: 0, length: ns.length)
        re.enumerateMatches(in: ns.string, range: range) { match, _, _ in
            if let r = match?.range {
                ns.addAttribute(.foregroundColor, value: color, range: r)
            }
        }
    }
}
