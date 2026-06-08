import Foundation

extension ClipboardItem {
    var effectiveFirstCopiedAt: Date { firstCopiedAt ?? createdAt }
    var effectiveLastCopiedAt: Date { lastCopiedAt ?? createdAt }
    var effectiveCopyCount: Int { max(copyCount, 1) }

    var pendingSuggestions: [CategorySuggestion] {
        CategorySuggestionCodec.decode(pendingSuggestionsJSON)
    }

    func setPendingSuggestions(_ suggestions: [CategorySuggestion]) {
        pendingSuggestionsJSON = CategorySuggestionCodec.encode(suggestions)
    }

    func clearPendingSuggestions() {
        pendingSuggestionsJSON = nil
    }

    /// Copies recorded today (calendar day, local timezone).
    func copiesTodayCount(calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: .now)
        let eventsToday = copyEvents.filter { $0.copiedAt >= start }.count
        if eventsToday > 0 { return eventsToday }
        if calendar.isDate(effectiveLastCopiedAt, inSameDayAs: .now) { return effectiveCopyCount }
        return 0
    }

    func sortedCopyEvents() -> [ClipboardCopyEvent] {
        copyEvents.sorted { $0.copiedAt > $1.copiedAt }
    }

    /// Distinct source app bundle IDs across all recorded copies (incl. base source).
    var distinctSourceBundleIDs: [String] {
        var seen = Set<String>()
        var out: [String] = []
        if let b = sourceAppBundleID, !b.isEmpty, seen.insert(b).inserted { out.append(b) }
        for e in copyEvents {
            if let b = e.sourceAppBundleID, !b.isEmpty, seen.insert(b).inserted { out.append(b) }
        }
        return out
    }

    /// Distinct source app display names across all recorded copies.
    var distinctSourceAppNames: [String] {
        var seen = Set<String>()
        var out: [String] = []
        if let n = sourceAppName, !n.isEmpty, seen.insert(n).inserted { out.append(n) }
        for e in copyEvents {
            if let n = e.sourceAppName, !n.isEmpty, seen.insert(n).inserted { out.append(n) }
        }
        return out
    }
}
