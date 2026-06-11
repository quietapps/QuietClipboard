import Foundation

enum SensitiveDetector {
    private static let patterns: [NSRegularExpression] = {
        let raw: [String] = [
            #"sk-[A-Za-z0-9_-]{20,}"#,          // OpenAI incl. sk-proj-, sk-ant-, etc.
            #"pk_(live|test)_[A-Za-z0-9]{16,}"#,
            #"rk_(live|test)_[A-Za-z0-9]{16,}"#,
            #"AKIA[0-9A-Z]{16}"#,
            #"ASIA[0-9A-Z]{16}"#,
            #"ghp_[A-Za-z0-9]{30,}"#,
            #"gho_[A-Za-z0-9]{20,}"#,
            #"gh[usr]_[A-Za-z0-9]{20,}"#,
            #"github_pat_[A-Za-z0-9_]{30,}"#,
            #"glpat-[A-Za-z0-9_-]{20,}"#,        // GitLab PAT
            #"AIza[0-9A-Za-z_\-]{35}"#,          // Google API key
            #"xox[bpasr]-[A-Za-z0-9-]{10,}"#,
            #"(?i)bearer\s+[A-Za-z0-9._-]{20,}"#,
            #"(?i)api[_-]?key\s*[:=]\s*['"]?[A-Za-z0-9_\-]{16,}"#,
            #"-----BEGIN[A-Z ]*PRIVATE KEY-----"#,
            #"ssh-(rsa|ed25519|dss)\s+[A-Za-z0-9+/=]{20,}"#,
            #"ecdsa-sha2-[A-Za-z0-9-]+\s+[A-Za-z0-9+/=]{20,}"#,
            #"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#,
        ]
        return raw.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static let envKeyPattern: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)(SECRET|PASSWORD|TOKEN|API[_-]?KEY|DATABASE_URL|PRIVATE_KEY|ACCESS_KEY)[A-Z0-9_]*\s*=\s*\S{4,}"#
    )

    private static let ccCandidateRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?<![0-9])(?:[0-9][ -]?){13,19}(?![0-9])"#
    )

    static func isSensitive(_ text: String, isConcealed: Bool) -> Bool {
        if isConcealed { return true }
        guard text.count >= 8 else { return false }
        // For very large pastes (dumped .env files, key bundles) scan the head and tail rather than
        // bailing — secrets cluster near the edges, and bailing would persist them in cleartext.
        let scanned: String
        if text.count > 200_000 {
            scanned = String(text.prefix(100_000)) + "\n" + String(text.suffix(100_000))
        } else {
            scanned = text
        }
        let nsr = NSRange(scanned.startIndex..., in: scanned)
        for re in patterns {
            if re.firstMatch(in: scanned, range: nsr) != nil { return true }
        }
        if envKeyPattern?.firstMatch(in: scanned, range: nsr) != nil { return true }
        if containsCreditCard(scanned) { return true }
        return false
    }

    private static func containsCreditCard(_ text: String) -> Bool {
        guard let ccCandidateRegex else { return false }
        let ns = text as NSString
        let matches = ccCandidateRegex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        for m in matches {
            let raw = ns.substring(with: m.range)
            let digits = raw.compactMap { $0.wholeNumberValue }
            guard digits.count >= 13, digits.count <= 19, luhnValid(digits) else { continue }
            // Require a real card length (15/16) or human digit grouping; rejects bare long IDs.
            if digits.count == 15 || digits.count == 16 || raw.contains(" ") || raw.contains("-") {
                return true
            }
        }
        return false
    }

    private static func luhnValid(_ digits: [Int]) -> Bool {
        var sum = 0
        let reversed = digits.reversed()
        for (i, d) in reversed.enumerated() {
            if i % 2 == 1 {
                let dd = d * 2
                sum += dd > 9 ? dd - 9 : dd
            } else {
                sum += d
            }
        }
        return sum % 10 == 0
    }
}
