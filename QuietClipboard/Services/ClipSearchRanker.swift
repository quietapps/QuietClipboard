import Foundation

/// On-device ranked search: substring-first, light typo tolerance (Levenshtein). Tuned for responsive typing.
enum ClipSearchRanker {
    private static let minScore: Double = 12
    /// Max items scored per query (most recent first in caller).
    private static let poolCap = 800
    private static let maxWordsPerField = 20
    /// Per-field cap on searched characters. Tradeoff: a needle whose first occurrence lies past
    /// this offset in a very large clip (e.g. a 500 KB log dump) is missed, but per-keystroke
    /// cost is bounded by the cap rather than by clip size. Users locate big clips by their
    /// opening lines/title in practice, so the recall loss is negligible compared to the cost of
    /// lowercasing and scanning half a megabyte per item on every keystroke.
    private static let maxSearchedCharsPerField = 16_384

    struct FieldWeight {
        let text: String
        let weight: Double
    }

    static func ranked(_ items: [ClipboardItem], query: String) -> [ClipboardItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }

        let tokens = queryTokens(q)
        let typeHint = contentTypeHint(for: q)

        // Exact / substring matching runs over the ENTIRE history so a clip deep in the past is
        // never silently missed. Only the expensive fuzzy (Levenshtein) pass is bounded to the
        // most-recent `poolCap` items for typing responsiveness (callers pass newest-first).
        let fingerprint = PoolFingerprint(items)
        let narrowed = narrowingCandidates(query: q, tokens: tokens, fingerprint: fingerprint)

        var tailGatePassed = Set<UUID>()
        var scored: [(ClipboardItem, Double)] = []
        scored.reserveCapacity(min(items.count, 256))
        for (idx, item) in items.enumerated() {
            if idx < poolCap {
                // Head pool (fuzzy-eligible): always scanned in full. Fuzzy matching is NOT
                // monotonic under query extension — a longer query can fuzzily reach a word the
                // shorter one could not — so the typing memo must never narrow this pool.
                let s = score(item, query: q, tokens: tokens, typeHint: typeHint, allowFuzzy: true)
                if s >= minScore { scored.append((item, s)) }
            } else {
                // Tail pool: the gate here is pure substring/token containment, which IS
                // monotonic under query extension (see narrowingCandidates) — an item that
                // failed the previous prefix query's gate cannot pass it now, so it is skipped
                // without touching the model at all.
                if let narrowed, !narrowed.contains(item.id) { continue }
                let hay = haystack(for: item)
                guard passesQuickGate(hay, query: q, tokens: tokens, allowFuzzy: false) else { continue }
                tailGatePassed.insert(item.id)
                let s = gatedScore(item, haystack: hay, query: q, tokens: tokens, typeHint: typeHint, allowFuzzy: false)
                if s >= minScore { scored.append((item, s)) }
            }
        }
        // Storing the memo wholesale on every call doubles as the reset for non-extension
        // queries (deletions, brand-new searches) and pool changes: the next call simply
        // fails the narrowing preconditions against the fresh memo and scans in full.
        memoBox.set(QueryMemo(query: q, tokens: tokens, fingerprint: fingerprint,
                              tailGatePassed: tailGatePassed, storedAt: .now))
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }

    static func matches(_ item: ClipboardItem, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return score(item, query: q, tokens: queryTokens(q), typeHint: contentTypeHint(for: q), allowFuzzy: true) >= minScore
    }

    // MARK: - Per-item haystack cache

    /// Pre-lowercased, length-capped searchable text for one item — derived once and reused
    /// across keystrokes instead of re-lowercasing every field on every keystroke.
    /// Immutable after init, so instances are safe to hand out from the shared cache.
    private final class Haystack {
        /// All searchable parts joined with spaces and lowercased — the cheap-gate target.
        let blob: String
        /// First `maxWordsPerField` words of `blob`. The fuzzy gate never looks past these, so
        /// precomputing them avoids re-splitting the blob per token on every keystroke.
        let gateWords: [String]
        /// Weighted fields with text already lowercased and capped.
        let fields: [FieldWeight]
        /// Approximate retained bytes, used as the NSCache cost.
        let cost: Int

        /// Validation stamps: a cache hit is served only while both still match. `modifiedAt`
        /// covers every per-item mutation (edits, transforms, enrichment, categorization —
        /// all bump it); `generation` covers category renames/deletions, which change
        /// searchable text without touching member items.
        let modifiedAt: Date
        let generation: UInt64

        init(item: ClipboardItem, generation: UInt64) {
            var blobParts: [String] = []
            var weighted: [FieldWeight] = []
            // Mirrors the pre-cache searchBlob/searchableFields exactly: the blob takes every
            // non-nil part (in this order), the fields take the non-empty ones with their weight.
            // Weights are unchanged; empty fields scored 0 before, so filtering them is neutral.
            func add(_ raw: String?, weight: Double) {
                guard let raw else { return }
                let part = String(raw.prefix(ClipSearchRanker.maxSearchedCharsPerField)).lowercased()
                blobParts.append(part)
                if !part.isEmpty { weighted.append(FieldWeight(text: part, weight: weight)) }
            }
            add(item.textContent, weight: 1.0)
            add(item.title, weight: 0.95)
            add(item.ocrText, weight: 0.85)
            add(item.linkPreviewTitle, weight: 0.8)
            add(item.sourceAppName, weight: 0.72)
            add(item.colorHex, weight: 0.5)
            add(item.contentType.displayName, weight: 0.55)
            for cat in item.categories {
                add(cat.name, weight: 0.48)
            }
            let joined = blobParts.joined(separator: " ")
            blob = joined
            gateWords = joined.split { !$0.isLetter && !$0.isNumber }
                .prefix(ClipSearchRanker.maxWordsPerField)
                .map(String.init)
            fields = weighted
            cost = joined.utf16.count * 2 + weighted.reduce(0) { $0 + $1.text.utf16.count * 2 }
            self.modifiedAt = item.modifiedAt
            self.generation = generation
        }
    }

    /// Haystack derivation (lowercasing + joining several potentially large strings) dominated
    /// per-keystroke cost when recomputed for every item. Cache it per item, keyed by the bare
    /// item UUID: the per-keystroke hit path is one NSCache lookup plus a `modifiedAt` compare.
    /// Validation lives INSIDE the entry (see `Haystack.modifiedAt`/`generation`) rather than in
    /// a composite string key — building a key that faults the `categories` relationship for
    /// every item on every keystroke costs more than the derivation it was caching.
    /// NSCache is thread-safe and `Haystack` is immutable, so the cache is safe from any context
    /// the ranker is called on; reading the item's fields still requires the caller to own the
    /// model's context (all current call sites are MainActor SwiftUI views, same as before).
    private nonisolated(unsafe) static let haystackCache: NSCache<NSUUID, Haystack> = {
        let cache = NSCache<NSUUID, Haystack>()
        cache.countLimit = 4096
        cache.totalCostLimit = 64 * 1024 * 1024 // bytes; worst-case blobs are ~100 KB each
        return cache
    }()

    /// Bumped when a category is renamed or deleted — the only searchable-text mutations that
    /// don't touch member items' `modifiedAt`. Entries from older generations fail validation
    /// and rebuild lazily on next access.
    private nonisolated(unsafe) static var storedGeneration: UInt64 = 0
    private static let generationLock = NSLock()

    static func invalidateHaystacks() {
        generationLock.lock()
        storedGeneration &+= 1
        generationLock.unlock()
    }

    private static var currentGeneration: UInt64 {
        generationLock.lock()
        defer { generationLock.unlock() }
        return storedGeneration
    }

    private static func haystack(for item: ClipboardItem) -> Haystack {
        let key = item.id as NSUUID
        let generation = currentGeneration
        if let cached = haystackCache.object(forKey: key),
           cached.modifiedAt == item.modifiedAt,
           cached.generation == generation {
            return cached
        }
        let entry = Haystack(item: item, generation: generation)
        haystackCache.setObject(entry, forKey: key, cost: entry.cost)
        return entry
    }

    /// Builds haystacks for the newest `limit` items ahead of time so the first search
    /// keystroke doesn't pay the entire derivation (and SwiftData row-faulting) cost in one
    /// frame. Yields between chunks to keep the main actor responsive; safe to re-run.
    /// Default matches `poolCap`: warming the fuzzy head pool covers the items people
    /// actually rank against, without front-loading row realization (and the blob memory
    /// it caches) for the whole history.
    @MainActor
    static func prewarmHaystacks(_ items: [ClipboardItem], limit: Int = poolCap) async {
        let pool = items.prefix(limit)
        var index = pool.startIndex
        while index < pool.endIndex {
            if Task.isCancelled { return }
            let end = pool.index(index, offsetBy: 150, limitedBy: pool.endIndex) ?? pool.endIndex
            for item in pool[index..<end] {
                _ = haystack(for: item)
            }
            index = end
            await Task.yield()
        }
    }

    // MARK: - Incremental narrowing (typing memo)

    /// Cheap identity check for "is this the same candidate array as the previous keystroke".
    /// Count plus first/middle/last item IDs: the ranker's callers all pass stable, newest-first
    /// arrays, so a capture, deletion, or filter/tab change perturbs at least one of these.
    private struct PoolFingerprint: Equatable {
        let count: Int
        let firstID: UUID?
        let midID: UUID?
        let lastID: UUID?

        init(_ items: [ClipboardItem]) {
            count = items.count
            firstID = items.first?.id
            midID = items.count > 2 ? items[items.count / 2].id : nil
            lastID = items.last?.id
        }
    }

    private struct QueryMemo {
        let query: String
        let tokens: [String]
        let fingerprint: PoolFingerprint
        /// IDs of tail items (index >= `poolCap`) that passed the cheap gate for `query`.
        let tailGatePassed: Set<UUID>
        let storedAt: Date
    }

    /// Lock-guarded box so the memo is safe from any calling context (call sites are currently
    /// all MainActor, but the ranker's API is nonisolated and must stay safe if that changes).
    private final class MemoBox: @unchecked Sendable {
        private let lock = NSLock()
        private var memo: QueryMemo?

        func get() -> QueryMemo? {
            lock.lock(); defer { lock.unlock() }
            return memo
        }

        func set(_ new: QueryMemo?) {
            lock.lock(); defer { lock.unlock() }
            memo = new
        }
    }

    private static let memoBox = MemoBox()

    /// Narrowing must never be applied across a pause long enough for background enrichment
    /// (OCR / link metadata) to add searchable text to an item the previous gate rejected.
    /// Mid-typing keystrokes arrive well inside this window; anything slower rescans in full.
    private static let memoMaxAge: TimeInterval = 3

    /// Returns the previous keystroke's tail gate-pass set when it can soundly restrict the
    /// current scan, or nil to scan in full.
    ///
    /// Soundness invariant — gate monotonicity under query extension: the tail gate passes iff
    /// `blob.contains(query)` or `blob.contains(token)` for some query token (no fuzzy branch
    /// in the tail). If the new query extends the old one as a prefix, `blob ⊇ newQuery ⟹
    /// blob ⊇ oldQuery`, so the whole-query branch only ever shrinks the match set. The token
    /// branch is an OR, so it is only monotonic when every NEW token still implies an OLD gate
    /// hit — which holds iff each new token contains the old query or some old token as a
    /// substring. Typing "swi" → "swif" qualifies; "swift " → "swift ba" does not (the fresh
    /// token "ba" can gate-pass items "swift" never matched), so narrowing is declined there.
    private static func narrowingCandidates(query: String, tokens: [String], fingerprint: PoolFingerprint) -> Set<UUID>? {
        guard query.count >= 2, let memo = memoBox.get() else { return nil }
        // Pool changed (capture, deletion, filter/tab change): membership and the
        // head/tail index split no longer line up with the recorded set.
        guard memo.fingerprint == fingerprint else { return nil }
        guard Date.now.timeIntervalSince(memo.storedAt) < memoMaxAge else { return nil }
        // Both queries are already trimmed + lowercased, so this is a case-insensitive
        // prefix check. Deletions and replacements fail it and trigger a full rescan.
        guard memo.query.count >= 2, query.hasPrefix(memo.query) else { return nil }
        for token in tokens {
            guard token.contains(memo.query) || memo.tokens.contains(where: { token.contains($0) }) else {
                return nil
            }
        }
        return memo.tailGatePassed
    }

    // MARK: - Scoring

    private static func score(
        _ item: ClipboardItem,
        query: String,
        tokens: [String],
        typeHint: ClipboardContentType?,
        allowFuzzy: Bool
    ) -> Double {
        let hay = haystack(for: item)
        guard passesQuickGate(hay, query: query, tokens: tokens, allowFuzzy: allowFuzzy) else {
            return 0
        }
        return gatedScore(item, haystack: hay, query: query, tokens: tokens, typeHint: typeHint, allowFuzzy: allowFuzzy)
    }

    /// Caller must have passed `passesQuickGate` for the same haystack and query.
    private static func gatedScore(
        _ item: ClipboardItem,
        haystack: Haystack,
        query: String,
        tokens: [String],
        typeHint: ClipboardContentType?,
        allowFuzzy: Bool
    ) -> Double {
        var best = 0.0
        for field in haystack.fields {
            best = max(best, fieldScore(field: field.text, weight: field.weight, query: query, tokens: tokens, allowFuzzy: allowFuzzy))
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
    private static func passesQuickGate(_ haystack: Haystack, query: String, tokens: [String], allowFuzzy: Bool) -> Bool {
        if haystack.blob.contains(query) { return true }
        if tokens.contains(where: { haystack.blob.contains($0) }) { return true }
        if allowFuzzy, query.count >= 3, fuzzyNeeded(tokens: tokens, haystack: haystack) {
            return true
        }
        return false
    }

    private static func fuzzyNeeded(tokens: [String], haystack: Haystack) -> Bool {
        for token in tokens where token.count >= 3 {
            for word in haystack.gateWords where abs(word.count - token.count) <= 2 {
                if levenshteinDistance(token, word, maxDistance: 2) <= 2 {
                    return true
                }
            }
        }
        return false
    }

    private static func fieldScore(
        field: String, // pre-lowercased and length-capped by the haystack cache
        weight: Double,
        query: String,
        tokens: [String],
        allowFuzzy: Bool
    ) -> Double {
        if field.contains(query) { return 100 * weight }
        if field.hasPrefix(query) { return 88 * weight }

        var tokenScore = 0.0
        for token in tokens where token.count >= 2 {
            if field.contains(token) {
                tokenScore += 72
                continue
            }
            guard allowFuzzy, token.count >= 3 else { continue }
            let words = field.split { !$0.isLetter && !$0.isNumber }.map(String.init)
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
