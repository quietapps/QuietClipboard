import Foundation

enum ClipSearchMatcher {
    /// Substring + fuzzy ranked filter (typo-tolerant, recency/type weighted).
    static func ranked(_ items: [ClipboardItem], query: String) -> [ClipboardItem] {
        ClipSearchRanker.ranked(items, query: query)
    }

    static func matches(_ item: ClipboardItem, query: String) -> Bool {
        ClipSearchRanker.matches(item, query: query)
    }
}
