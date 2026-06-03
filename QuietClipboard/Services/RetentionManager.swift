import Foundation
import SwiftData

/// Manual cleanup windows (non-favorites only).
enum CleanupAgeOption: String, CaseIterable, Identifiable {
    case hours24
    case hours48
    case days7
    case days15
    case days30
    case days90

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hours24: return "24 hours"
        case .hours48: return "48 hours"
        case .days7: return "7 days"
        case .days15: return "15 days"
        case .days30: return "30 days"
        case .days90: return "90 days"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .hours24: return 24 * 3600
        case .hours48: return 48 * 3600
        case .days7: return 7 * 24 * 3600
        case .days15: return 15 * 24 * 3600
        case .days30: return 30 * 24 * 3600
        case .days90: return 90 * 24 * 3600
        }
    }
}

@MainActor
final class RetentionManager {
    private let container: ModelContainer
    private var task: Task<Void, Never>?

    init(container: ModelContainer) {
        self.container = container
    }

    func start() {
        runOnce()
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 24 * 60 * 60 * 1_000_000_000)
                self?.runOnce()
            }
        }
    }

    func stop() { task?.cancel(); task = nil }

    func runOnce() {
        guard let days = Preferences.retention.days else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let context = ModelContext(container)
        let desc = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isFavorite && $0.createdAt < cutoff }
        )
        guard let items = try? context.fetch(desc) else { return }
        for item in items {
            context.delete(item)
        }
        try? context.save()
    }

    func clearAll() {
        let context = ModelContext(container)
        let desc = FetchDescriptor<ClipboardItem>()
        guard let items = try? context.fetch(desc) else { return }
        for item in items { context.delete(item) }
        try? context.save()
    }

    func clearNonFavorites() {
        let context = ModelContext(container)
        let desc = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isFavorite }
        )
        guard let items = try? context.fetch(desc) else { return }
        for item in items { context.delete(item) }
        try? context.save()
    }

    /// Deletes non-favorited items whose last copy time is older than `interval`.
    @discardableResult
    func clearOlderThan(interval: TimeInterval) -> Int {
        let cutoff = Date.now.addingTimeInterval(-interval)
        let context = ModelContext(container)
        let desc = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isFavorite }
        )
        guard let items = try? context.fetch(desc) else { return 0 }
        let stale = items.filter { $0.effectiveLastCopiedAt < cutoff }
        for item in stale { context.delete(item) }
        try? context.save()
        return stale.count
    }

    func clearOlderThan(days: Int) {
        clearOlderThan(interval: TimeInterval(days) * 24 * 3600)
    }

    func clearOlderThan(_ option: CleanupAgeOption) -> Int {
        clearOlderThan(interval: option.interval)
    }

    func countOlderThan(_ option: CleanupAgeOption) -> Int {
        let cutoff = Date.now.addingTimeInterval(-option.interval)
        let context = ModelContext(container)
        let desc = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isFavorite }
        )
        guard let items = try? context.fetch(desc) else { return 0 }
        return items.filter { $0.effectiveLastCopiedAt < cutoff }.count
    }

    struct HistoryCounts {
        var total: Int
        var favorites: Int
        var nonFavorites: Int { total - favorites }
    }

    func historyCounts() -> HistoryCounts {
        let context = ModelContext(container)
        let total = (try? context.fetchCount(FetchDescriptor<ClipboardItem>())) ?? 0
        let favDesc = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.isFavorite })
        let favorites = (try? context.fetchCount(favDesc)) ?? 0
        return HistoryCounts(total: total, favorites: favorites)
    }

    func clearType(_ type: ClipboardContentType) {
        let raw = type.rawValue
        let context = ModelContext(container)
        let desc = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isFavorite && $0.contentTypeRaw == raw }
        )
        guard let items = try? context.fetch(desc) else { return }
        for item in items { context.delete(item) }
        try? context.save()
    }

    static func storageUsage() -> Int64 {
        let fm = FileManager.default
        guard let base = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: false) else { return 0 }
        let dir = base.appendingPathComponent("QuietClipboard", isDirectory: true)
        return folderSize(dir)
    }

    private static func folderSize(_ url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey],
                                              options: [], errorHandler: nil) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }
}
