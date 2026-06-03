import Foundation
import SwiftData
import CryptoKit

enum DuplicateDetectionService {
    static func normalizedFingerprint(text: String?, contentType: ClipboardContentType, contentHash: String) -> String {
        guard let text, !text.isEmpty,
              contentType == .text || contentType == .code || contentType == .link
                || contentType == .richText || contentType == .markdown else {
            return "hash:\(contentHash)"
        }
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let slice = String(normalized.prefix(2000))
        let digest = SHA256.hash(data: Data(slice.utf8))
        return "text:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    static func textSimilarity(_ a: String, _ b: String) -> Double {
        let na = normalizeForCompare(a)
        let nb = normalizeForCompare(b)
        guard !na.isEmpty, !nb.isEmpty else { return na == nb ? 1 : 0 }
        if na == nb { return 1 }
        let longer = max(na.count, nb.count)
        guard longer > 0 else { return 0 }
        let dist = levenshtein(na, nb)
        return 1 - Double(dist) / Double(longer)
    }

    static func assignNearDuplicateGroup(
        item: ClipboardItem,
        context: ModelContext,
        threshold: Double = 0.92
    ) {
        guard let text = item.textContent, text.count >= 20 else { return }
        var desc = FetchDescriptor<ClipboardItem>()
        desc.fetchLimit = 200
        guard let candidates = try? context.fetch(desc) else { return }

        for other in candidates where other.id != item.id {
            guard other.contentType == item.contentType,
                  other.contentHash != item.contentHash,
                  let otherText = other.textContent else { continue }
            let sim = textSimilarity(text, otherText)
            if sim >= threshold {
                let group = other.duplicateGroupID ?? other.id
                item.duplicateGroupID = group
                if other.duplicateGroupID == nil {
                    other.duplicateGroupID = group
                }
                return
            }
        }
    }

    private static func normalizeForCompare(_ s: String) -> String {
        s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func levenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        var dist = Array(repeating: Array(repeating: 0, count: bChars.count + 1), count: aChars.count + 1)
        for i in 0...aChars.count { dist[i][0] = i }
        for j in 0...bChars.count { dist[0][j] = j }
        for i in 1...aChars.count {
            for j in 1...bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                dist[i][j] = min(dist[i - 1][j] + 1, dist[i][j - 1] + 1, dist[i - 1][j - 1] + cost)
            }
        }
        return dist[aChars.count][bChars.count]
    }
}
