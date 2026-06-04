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

    static func textSimilarity(_ a: String, _ b: String, threshold: Double = 0) -> Double {
        let na = normalizeForCompare(a)
        let nb = normalizeForCompare(b)
        guard !na.isEmpty, !nb.isEmpty else { return na == nb ? 1 : 0 }
        if na == nb { return 1 }
        let longer = max(na.count, nb.count)
        let shorter = min(na.count, nb.count)
        guard longer > 0 else { return 0 }
        // Length pre-filter: edit distance ≥ length delta, so very different lengths can't be similar.
        if threshold > 0, Double(shorter) / Double(longer) < threshold { return 0 }
        // Only compute as much distance as the threshold allows, then early-exit.
        let maxDist = threshold > 0 ? Int((1 - threshold) * Double(longer)) + 1 : longer
        let dist = levenshtein(Array(na), Array(nb), maxDistance: maxDist)
        return 1 - Double(dist) / Double(longer)
    }

    static func assignNearDuplicateGroup(
        item: ClipboardItem,
        context: ModelContext,
        threshold: Double = 0.92
    ) {
        guard let text = item.textContent, text.count >= 20 else { return }
        var desc = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        desc.fetchLimit = 200
        guard let candidates = try? context.fetch(desc) else { return }

        for other in candidates where other.id != item.id {
            guard other.contentType == item.contentType,
                  other.contentHash != item.contentHash,
                  let otherText = other.textContent else { continue }
            let sim = textSimilarity(text, otherText, threshold: threshold)
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
        let n = s.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // Cap the compared length so a pair of huge clips can't allocate a giant DP row.
        return String(n.prefix(2000))
    }

    /// Two-row Levenshtein with early exit once the best achievable distance exceeds `maxDistance`.
    /// O(min(n,m)) memory instead of the full O(n·m) matrix.
    private static func levenshtein(_ a: [Character], _ b: [Character], maxDistance: Int) -> Int {
        let n = a.count, m = b.count
        if abs(n - m) > maxDistance { return maxDistance + 1 }
        if n == 0 { return m }
        if m == 0 { return n }
        var prev = Array(0...m)
        var curr = [Int](repeating: 0, count: m + 1)
        for i in 1...n {
            curr[0] = i
            var rowMin = curr[0]
            for j in 1...m {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
                rowMin = min(rowMin, curr[j])
            }
            if rowMin > maxDistance { return maxDistance + 1 }
            swap(&prev, &curr)
        }
        return prev[m]
    }
}
