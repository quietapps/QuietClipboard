import Foundation

enum StructuredDataDetector {
    /// First match when the entire trimmed clip is a single structured value.
    static func primaryMatch(in text: String) -> StructuredDataMatch? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\n") else { return nil }
        for kind in detectionOrder {
            if let match = matchKind(kind, in: trimmed, allowEmbedded: false) {
                return match
            }
        }
        return nil
    }

    /// All distinct matches in text (for detail chips).
    static func allMatches(in text: String, limit: Int = 8) -> [StructuredDataMatch] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        // Regex over multi‑MB blobs is expensive and can hit NSString edge cases; scan a prefix.
        let scanned = trimmed.count > 32_768 ? String(trimmed.prefix(32_768)) : trimmed
        if let primary = primaryMatch(in: scanned) { return [primary] }

        var found: [StructuredDataMatch] = []
        var seen = Set<String>()
        for kind in detectionOrder {
            guard found.count < limit else { break }
            if let m = matchKind(kind, in: scanned, allowEmbedded: true), seen.insert(m.normalized).inserted {
                found.append(m)
            }
        }
        return found
    }

    static func parseISODate(_ value: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: value) { return d }
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: value) { return d }
        f.formatOptions = [.withFullDate]
        return f.date(from: value)
    }

    private static let detectionOrder: [StructuredDataKind] = [
        .email, .uuid, .iban, .ipAddress, .semver, .isoDate, .phone
    ]

    private static func matchKind(
        _ kind: StructuredDataKind,
        in text: String,
        allowEmbedded: Bool
    ) -> StructuredDataMatch? {
        switch kind {
        case .email: return matchEmail(text, allowEmbedded: allowEmbedded)
        case .phone: return matchPhone(text, allowEmbedded: allowEmbedded)
        case .uuid: return matchUUID(text, allowEmbedded: allowEmbedded)
        case .isoDate: return matchISODate(text, allowEmbedded: allowEmbedded)
        case .iban: return matchIBAN(text, allowEmbedded: allowEmbedded)
        case .ipAddress: return matchIP(text, allowEmbedded: allowEmbedded)
        case .semver: return matchSemver(text, allowEmbedded: allowEmbedded)
        }
    }

    // MARK: - Email

    private static let emailRegex = try! NSRegularExpression(
        pattern: #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#,
        options: [.caseInsensitive]
    )
    private static let emailEmbedded = try! NSRegularExpression(
        pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
        options: [.caseInsensitive]
    )

    private static func matchEmail(_ text: String, allowEmbedded: Bool) -> StructuredDataMatch? {
        let re = allowEmbedded && !isFullMatch(emailRegex, in: text) ? emailEmbedded : emailRegex
        guard let raw = firstMatch(re, in: text, fullString: text, allowEmbedded: allowEmbedded) else { return nil }
        let norm = raw.lowercased()
        return StructuredDataMatch(kind: .email, raw: raw, normalized: norm)
    }

    // MARK: - UUID

    private static let uuidRegex = try! NSRegularExpression(
        pattern: #"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#,
        options: [.caseInsensitive]
    )
    private static let uuidEmbedded = try! NSRegularExpression(
        pattern: #"\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b"#,
        options: [.caseInsensitive]
    )

    private static func matchUUID(_ text: String, allowEmbedded: Bool) -> StructuredDataMatch? {
        let re = allowEmbedded && !isFullMatch(uuidRegex, in: text) ? uuidEmbedded : uuidRegex
        guard let raw = firstMatch(re, in: text, fullString: text, allowEmbedded: allowEmbedded) else { return nil }
        return StructuredDataMatch(kind: .uuid, raw: raw, normalized: raw.lowercased())
    }

    // MARK: - IBAN

    private static func matchIBAN(_ text: String, allowEmbedded: Bool) -> StructuredDataMatch? {
        let compact = text.replacingOccurrences(of: " ", with: "").uppercased()
        let candidate = allowEmbedded ? extractIBAN(from: text) : compact
        guard let raw = candidate, isValidIBAN(raw) else { return nil }
        return StructuredDataMatch(kind: .iban, raw: raw, normalized: raw)
    }

    private static func extractIBAN(from text: String) -> String? {
        let pattern = #"\b[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}\b"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let upper = text.uppercased()
        guard let range = safeFullNSRange(in: upper) else { return nil }
        guard let m = re.firstMatch(in: upper, range: range),
              let r = Range(m.range, in: upper) else { return nil }
        let s = String(upper[r]).replacingOccurrences(of: " ", with: "")
        return isValidIBAN(s) ? s : nil
    }

    private static func isValidIBAN(_ iban: String) -> Bool {
        guard iban.count >= 15, iban.count <= 34 else { return false }
        guard iban.unicodeScalars.prefix(2).allSatisfy({ CharacterSet.letters.contains($0) }) else { return false }
        var rearranged = String(iban.dropFirst(4) + iban.prefix(4))
        rearranged = rearranged.unicodeScalars.map { scalar -> String in
            if CharacterSet.decimalDigits.contains(scalar) {
                return String(scalar)
            }
            let value = Int(scalar.value) - Int(("A" as UnicodeScalar).value) + 10
            return String(value)
        }.joined()
        var remainder = 0
        for ch in rearranged {
            guard let digit = ch.wholeNumberValue else { return false }
            remainder = (remainder * 10 + digit) % 97
        }
        return remainder == 1
    }

    // MARK: - IP

    private static let ipv4Regex = try! NSRegularExpression(
        pattern: #"^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)$"#
    )
    private static let ipv6Regex = try! NSRegularExpression(
        pattern: #"^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|(::[0-9a-fA-F]{1,4}(:[0-9a-fA-F]{1,4}){0,6})|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4})$"#
    )

    private static func matchIP(_ text: String, allowEmbedded: Bool) -> StructuredDataMatch? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isFullMatch(ipv4Regex, in: trimmed) {
            return StructuredDataMatch(kind: .ipAddress, raw: trimmed, normalized: trimmed)
        }
        if isFullMatch(ipv6Regex, in: trimmed) {
            let norm = trimmed.lowercased()
            return StructuredDataMatch(kind: .ipAddress, raw: trimmed, normalized: norm)
        }
        if allowEmbedded {
            if let raw = firstMatch(ipv4Regex, in: trimmed, fullString: trimmed, allowEmbedded: true) {
                return StructuredDataMatch(kind: .ipAddress, raw: raw, normalized: raw)
            }
        }
        return nil
    }

    // MARK: - Semver

    private static let semverRegex = try! NSRegularExpression(
        pattern: #"^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[\w.-]+)?(?:\+[\w.-]+)?$"#
    )

    private static func matchSemver(_ text: String, allowEmbedded: Bool) -> StructuredDataMatch? {
        guard let raw = firstMatch(semverRegex, in: text, fullString: text, allowEmbedded: allowEmbedded) else { return nil }
        var norm = raw
        if norm.hasPrefix("v") { norm.removeFirst() }
        return StructuredDataMatch(kind: .semver, raw: raw, normalized: norm)
    }

    // MARK: - ISO date

    private static let isoDateRegex = try! NSRegularExpression(
        pattern: #"^\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}:\d{2}(?:\.\d{1,9})?(?:Z|[+-]\d{2}:?\d{2})?)?$"#
    )

    private static func matchISODate(_ text: String, allowEmbedded: Bool) -> StructuredDataMatch? {
        guard let raw = firstMatch(isoDateRegex, in: text, fullString: text, allowEmbedded: allowEmbedded),
              let date = parseISODate(raw) else { return nil }
        let norm = ISO8601DateFormatter().string(from: date)
        return StructuredDataMatch(kind: .isoDate, raw: raw, normalized: norm)
    }

    // MARK: - Phone

    private static let phoneEmbedded = try! NSRegularExpression(
        pattern: #"\+?[0-9][0-9().\-\s]{8,28}[0-9]"#
    )

    private static func matchPhone(_ text: String, allowEmbedded: Bool) -> StructuredDataMatch? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate: String
        if allowEmbedded, !isPhoneLikeFullString(trimmed) {
            guard let raw = firstMatch(phoneEmbedded, in: trimmed, fullString: trimmed, allowEmbedded: true) else {
                return nil
            }
            candidate = raw
        } else {
            guard isPhoneLikeFullString(trimmed) else { return nil }
            candidate = trimmed
        }

        let digits = candidate.filter(\.isNumber)
        guard digits.count >= 10, digits.count <= 15 else { return nil }

        var normalized: String
        if candidate.contains("+") || digits.count > 10 {
            normalized = "+" + digits
        } else if digits.count == 10 {
            normalized = "+1" + digits
        } else {
            normalized = "+" + digits
        }
        return StructuredDataMatch(kind: .phone, raw: candidate, normalized: normalized)
    }

    private static func isPhoneLikeFullString(_ text: String) -> Bool {
        guard text.count <= 32 else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789+().- ")
        return text.unicodeScalars.allSatisfy({ allowed.contains($0) }) && text.contains(where: \.isNumber)
    }

    // MARK: - Helpers

    private static func isFullMatch(_ regex: NSRegularExpression, in text: String) -> Bool {
        guard let range = safeFullNSRange(in: text) else { return false }
        guard let m = regex.firstMatch(in: text, range: range) else { return false }
        return m.range.location == 0 && m.range.length == range.length
    }

    private static func firstMatch(
        _ regex: NSRegularExpression,
        in text: String,
        fullString: String,
        allowEmbedded: Bool
    ) -> String? {
        guard let range = safeFullNSRange(in: fullString) else { return nil }
        guard let m = regex.firstMatch(in: fullString, range: range),
              let r = Range(m.range, in: fullString) else { return nil }
        if !allowEmbedded && (m.range.location != 0 || m.range.length != range.length) { return nil }
        return String(fullString[r])
    }

    private static func safeFullNSRange(in text: String) -> NSRange? {
        let ns = text as NSString
        guard ns.length > 0 else { return nil }
        return NSRange(location: 0, length: ns.length)
    }
}
