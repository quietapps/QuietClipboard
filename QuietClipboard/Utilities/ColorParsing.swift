import Foundation

enum ColorParsing {
    static let hexRegex = try! NSRegularExpression(
        pattern: #"^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{3}|[0-9a-fA-F]{8})$"#
    )
    static let rgbRegex = try! NSRegularExpression(
        pattern: #"^rgba?\(\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*(?:,\s*[\d.]+\s*)?\)$"#,
        options: [.caseInsensitive]
    )
    static let hslRegex = try! NSRegularExpression(
        pattern: #"^hsla?\(\s*\d{1,3}\s*,\s*\d{1,3}%\s*,\s*\d{1,3}%\s*(?:,\s*[\d.]+\s*)?\)$"#,
        options: [.caseInsensitive]
    )

    static func isColorString(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 32 else { return false }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        if hexRegex.firstMatch(in: trimmed, range: range) != nil { return true }
        if rgbRegex.firstMatch(in: trimmed, range: range) != nil { return true }
        if hslRegex.firstMatch(in: trimmed, range: range) != nil { return true }
        return false
    }

    static func hexFrom(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        if hexRegex.firstMatch(in: trimmed, range: range) != nil {
            return trimmed.hasPrefix("#") ? trimmed.uppercased() : "#" + trimmed.uppercased()
        }
        return nil
    }
}
