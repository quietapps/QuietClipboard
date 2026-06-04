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

    /// Canonical `#RRGGBB`(`AA`) hex for any supported color syntax, so `#f00`, `#FF0000`,
    /// `rgb(255,0,0)` and `hsl(0,100%,50%)` all normalize to one value (dedup + swatches).
    static func hexFrom(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        if hexRegex.firstMatch(in: trimmed, range: range) != nil {
            let body = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
            return "#" + expandShortHex(body).uppercased()
        }
        if rgbRegex.firstMatch(in: trimmed, range: range) != nil {
            let n = numbers(in: trimmed)
            if n.count >= 3 { return hex(Int(n[0]), Int(n[1]), Int(n[2])) }
        }
        if hslRegex.firstMatch(in: trimmed, range: range) != nil {
            let n = numbers(in: trimmed)
            if n.count >= 3, let rgb = hslToRGB(h: n[0], s: n[1], l: n[2]) {
                return hex(rgb.0, rgb.1, rgb.2)
            }
        }
        return nil
    }

    private static func expandShortHex(_ hex: String) -> String {
        hex.count == 3 ? hex.map { "\($0)\($0)" }.joined() : hex
    }

    private static func clampByte(_ v: Int) -> Int { min(255, max(0, v)) }

    private static func hex(_ r: Int, _ g: Int, _ b: Int) -> String {
        String(format: "#%02X%02X%02X", clampByte(r), clampByte(g), clampByte(b))
    }

    private static func hslToRGB(h: Double, s: Double, l: Double) -> (Int, Int, Int)? {
        let hue = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        let sat = max(0, min(1, s / 100))
        let lum = max(0, min(1, l / 100))
        if sat == 0 {
            let v = Int((lum * 255).rounded())
            return (v, v, v)
        }
        let q = lum < 0.5 ? lum * (1 + sat) : lum + sat - lum * sat
        let p = 2 * lum - q
        func hue2rgb(_ t0: Double) -> Double {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6.0 { return p + (q - p) * 6 * t }
            if t < 1.0 / 2.0 { return q }
            if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6 }
            return p
        }
        return (Int((hue2rgb(hue + 1.0 / 3.0) * 255).rounded()),
                Int((hue2rgb(hue) * 255).rounded()),
                Int((hue2rgb(hue - 1.0 / 3.0) * 255).rounded()))
    }

    private static let numberRegex = try! NSRegularExpression(pattern: #"[0-9]+(?:\.[0-9]+)?"#)

    private static func numbers(in s: String) -> [Double] {
        let ns = s as NSString
        return numberRegex.matches(in: s, range: NSRange(location: 0, length: ns.length))
            .compactMap { Double(ns.substring(with: $0.range)) }
    }
}
