import Foundation

/// On-device ranked search: substring-first, light typo tolerance (Levenshtein). Tuned for responsive typing.
enum ClipSearchRanker {
    private static let minScore: Double = 12
    /// Max items scored per query (most recent first in caller).
    private static let poolCap = 800
    private static let maxWordsPerField = 20

    struct FieldWeight {
        let text: String
        let weight: Double
    }

    static func ranked(_ items: [ClipboardItem], query: String) -> [ClipboardItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }

        let tokens = queryTokens(q)
        let typeHint = contentTypeHint(for: q)
        let pool = items.count > poolCap ? Array(items.prefix(poolCap)) : items

        return pool
            .compactMap { item -> (ClipboardItem, Double)? in
                let score = score(item, query: q, tokens: tokens, typeHint: typeHint)
                return score >= minScore ? (item, score) : nil
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    static func matches(_ item: ClipboardItem, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return score(item, query: q, tokens: queryTokens(q), typeHint: contentTypeHint(for: q)) >= minScore
    }

    // MARK: - Scoring

    private static func score(
        _ item: ClipboardItem,
        query: String,
        tokens: [String],
        typeHint: ClipboardContentType?
    ) -> Double {
        guard passesQuickGate(item, query: query, tokens: tokens) else {
            return 0
        }

        var best = 0.0
        for field in searchableFields(item) {
            best = max(best, fieldScore(field: field.text, weight: field.weight, query: query, tokens: tokens))
            if best >= 95 { break }
        }

        if item.isUniversalClipboardSource, matchesUniversalClipboardQuery(query) {
            best = max(best, 55)
        }

        if let typeHint, item.contentType == typeHint {
            best += 18
        } else if tokens.count == 1,
                  item.contentType.displayName.lowercased().contains(tokens[0]) {
            best += 12
        }

        best += recencyBoost(for: item.effectiveLastCopiedAt)
        return best
    }

    /// Cheap gate before full field scoring.
    private static func passesQuickGate(_ item: ClipboardItem, query: String, tokens: [String]) -> Bool {
        let blob = searchBlob(for: item)
        if blob.contains(query) { return true }
        if tokens.contains(where: { blob.contains($0) }) { return true }
        if query.count >= 3, fuzzyNeeded(query: query, tokens: tokens, blob: blob) {
            return true
        }
        return false
    }

    private static func fuzzyNeeded(query: String, tokens: [String], blob: String) -> Bool {
        for token in tokens where token.count >= 3 {
            let words = blob.split { !$0.isLetter && !$0.isNumber }.map(String.init)
            for word in words.prefix(maxWordsPerField) where abs(word.count - token.count) <= 2 {
                if levenshteinDistance(token, word, maxDistance: 2) <= 2 {
                    return true
                }
            }
        }
        return false
    }

    private static func searchBlob(for item: ClipboardItem) -> String {
        var parts: [String] = []
        if let t = item.textContent { parts.append(t) }
        if let t = item.title { parts.append(t) }
        if let t = item.ocrText { parts.append(t) }
        if let t = item.linkPreviewTitle { parts.append(t) }
        if let t = item.sourceAppName { parts.append(t) }
        if let t = item.colorHex { parts.append(t) }
        parts.append(item.contentType.displayName)
        for cat in item.categories { parts.append(cat.name) }
        return parts.joined(separator: " ").lowercased()
    }

    private static func searchableFields(_ item: ClipboardItem) -> [FieldWeight] {
        var fields: [FieldWeight] = []
        if let t = item.textContent, !t.isEmpty { fields.append(.init(text: t, weight: 1.0)) }
        if let t = item.title, !t.isEmpty { fields.append(.init(text: t, weight: 0.95)) }
        if let t = item.ocrText, !t.isEmpty { fields.append(.init(text: t, weight: 0.85)) }
        if let t = item.linkPreviewTitle, !t.isEmpty { fields.append(.init(text: t, weight: 0.8)) }
        if let t = item.sourceAppName, !t.isEmpty { fields.append(.init(text: t, weight: 0.72)) }
        if let t = item.colorHex, !t.isEmpty { fields.append(.init(text: t, weight: 0.5)) }
        fields.append(.init(text: item.contentType.displayName, weight: 0.55))
        for cat in item.categories {
            fields.append(.init(text: cat.name, weight: 0.48))
        }
        return fields
    }

    private static func fieldScore(
        field: String,
        weight: Double,
        query: String,
        tokens: [String]
    ) -> Double {
        let hay = field.lowercased()
        if hay.contains(query) { return 100 * weight }
        if hay.hasPrefix(query) { return 88 * weight }

        var tokenScore = 0.0
        for token in tokens where token.count >= 2 {
            if hay.contains(token) {
                tokenScore += 72
                continue
            }
            guard token.count >= 3 else { continue }
            let words = hay.split { !$0.isLetter && !$0.isNumber }.map(String.init)
            var bestWord = 0.0
            for word in words.prefix(maxWordsPerField) where word.count >= 2 {
                if abs(word.count - token.count) > 2 { continue }
                bestWord = max(bestWord, fuzzyWordScore(query: token, candidate: word))
                if bestWord >= 70 { break }
            }
            tokenScore += bestWord
        }

        if tokens.count > 1 {
            tokenScore /= Double(tokens.count)
        }
        return tokenScore * weight
    }

    private static func fuzzyWordScore(query: String, candidate: String) -> Double {
        if candidate == query { return 85 }
        if candidate.hasPrefix(query) || query.hasPrefix(candidate) { return 70 }

        let maxDist = query.count <= 4 ? 1 : 2
        let dist = levenshteinDistance(query, candidate, maxDistance: maxDist)
        if dist <= maxDist {
            return 58 - Double(dist) * 14
        }
        return 0
    }

    private static func recencyBoost(for date: Date) -> Double {
        let days = max(0, Date.now.timeIntervalSince(date) / 86_400)
        if days <= 1 { return 22 }
        if days <= 7 { return 16 }
        if days <= 30 { return 10 }
        if days <= 90 { return 4 }
        return 0
    }

    private static func contentTypeHint(for query: String) -> ClipboardContentType? {
        ClipboardContentType.allCases.first { type in
            let name = type.displayName.lowercased()
            let raw = type.rawValue.lowercased()
            return query == name || query == raw || name.hasPrefix(query) || raw.hasPrefix(query)
        }
    }

    private static func queryTokens(_ query: String) -> [String] {
        query.split { !$0.isLetter && !$0.isNumber }
            .map { String($0).lowercased() }
            .filter { $0.count >= 2 }
    }

    private static func matchesUniversalClipboardQuery(_ q: String) -> Bool {
        let terms = ["iphone", "ipad", "handoff", "universal", "icloud", "ios", "watch", "vision"]
        return terms.contains(where: { q.contains($0) })
    }

    // MARK: - Levenshtein (bounded)

    private static func levenshteinDistance(_ a: String, _ b: String, maxDistance: Int) -> Int {
        if a == b { return 0 }
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        if abs(a.count - b.count) > maxDistance { return maxDistance + 1 }

        let aChars = Array(a)
        let bChars = Array(b)
        var prev = Array(0...bChars.count)
        var curr = Array(repeating: 0, count: bChars.count + 1)

        for i in 1...aChars.count {
            curr[0] = i
            var rowMin = curr[0]
            for j in 1...bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,
                    curr[j - 1] + 1,
                    prev[j - 1] + cost
                )
                rowMin = min(rowMin, curr[j])
            }
            if rowMin > maxDistance { return maxDistance + 1 }
            swap(&prev, &curr)
        }
        return prev[bChars.count]
    }
}
