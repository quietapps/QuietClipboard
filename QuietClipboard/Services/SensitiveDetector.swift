import Foundation

enum SensitiveDetector {
    private static let patterns: [NSRegularExpression] = {
        let raw: [String] = [
            #"sk-[A-Za-z0-9]{20,}"#,
            #"pk_(live|test)_[A-Za-z0-9]{16,}"#,
            #"AKIA[0-9A-Z]{16}"#,
            #"ghp_[A-Za-z0-9]{30,}"#,
            #"gho_[A-Za-z0-9]{30,}"#,
            #"github_pat_[A-Za-z0-9_]{30,}"#,
            #"xox[bpas]-[A-Za-z0-9-]{10,}"#,
            #"(?i)bearer\s+[A-Za-z0-9._-]{20,}"#,
            #"(?i)api[_-]?key\s*[:=]\s*['"]?[A-Za-z0-9_\-]{16,}"#,
            #"-----BEGIN[A-Z ]*PRIVATE KEY-----"#,
            #"ssh-(rsa|ed25519|dss)\s+[A-Za-z0-9+/=]{20,}"#,
            #"ecdsa-sha2-[A-Za-z0-9-]+\s+[A-Za-z0-9+/=]{20,}"#,
            #"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#,
        ]
        return raw.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    private static let envKeyPattern = try! NSRegularExpression(
        pattern: #"(?i)(SECRET|PASSWORD|TOKEN|API[_-]?KEY|DATABASE_URL|PRIVATE_KEY|ACCESS_KEY)[A-Z0-9_]*\s*=\s*\S{4,}"#
    )

    static func isSensitive(_ text: String, isConcealed: Bool) -> Bool {
        if isConcealed { return true }
        guard text.count >= 8, text.count <= 200_000 else { return false }
        let nsr = NSRange(text.startIndex..., in: text)
        for re in patterns {
            if re.firstMatch(in: text, range: nsr) != nil { return true }
        }
        if envKeyPattern.firstMatch(in: text, range: nsr) != nil { return true }
        if containsCreditCard(text) { return true }
        return false
    }

    private static func containsCreditCard(_ text: String) -> Bool {
        let digits = text.filter { $0.isNumber || $0 == "-" || $0 == " " }
        guard !digits.isEmpty else { return false }
        var current: [Int] = []
        var hits: [String] = []
        for ch in digits {
            if let d = ch.wholeNumberValue {
                current.append(d)
                if current.count > 19 { current.removeFirst() }
                if current.count >= 13, luhnValid(current) {
                    hits.append(current.map(String.init).joined())
                }
            } else {
                current.removeAll()
            }
        }
        return !hits.isEmpty
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
