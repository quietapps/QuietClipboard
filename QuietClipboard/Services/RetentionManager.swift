import Foundation
import SwiftData

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

    func clearOlderThan(days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        let context = ModelContext(container)
        let desc = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { !$0.isFavorite && $0.createdAt < cutoff }
        )
        guard let items = try? context.fetch(desc) else { return }
        for item in items { context.delete(item) }
        try? context.save()
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
