import Foundation

enum ClipSearchMatcher {
    static func matches(_ item: ClipboardItem, query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }

        if (item.textContent?.lowercased().contains(q) ?? false)
            || (item.title?.lowercased().contains(q) ?? false)
            || (item.ocrText?.lowercased().contains(q) ?? false)
            || (item.linkPreviewTitle?.lowercased().contains(q) ?? false)
            || (item.sourceAppName?.lowercased().contains(q) ?? false)
            || (item.colorHex?.lowercased().contains(q) ?? false) {
            return true
        }

        if item.isUniversalClipboardSource, matchesUniversalClipboardQuery(q) {
            return true
        }

        return false
    }

    private static func matchesUniversalClipboardQuery(_ q: String) -> Bool {
        let terms = ["iphone", "ipad", "handoff", "universal", "icloud", "ios", "watch", "vision"]
        return terms.contains(where: { q.contains($0) })
    }
}
