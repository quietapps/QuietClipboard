import Foundation
import SwiftData

struct ClipboardUsageStats: Equatable {
    struct DayCount: Identifiable, Equatable {
        var id: Date { day }
        let day: Date
        let count: Int
    }

    struct NamedCount: Identifiable, Equatable {
        var id: String { name }
        let name: String
        let count: Int
    }

    struct HourCount: Identifiable, Equatable {
        var id: Int { hour }
        let hour: Int
        let count: Int
    }

    let copiesPerDay: [DayCount]
    let topApps: [NamedCount]
    let topTypes: [NamedCount]
    let busiestHours: [HourCount]
    let totalCopyEvents: Int

    static let empty = ClipboardUsageStats(
        copiesPerDay: [],
        topApps: [],
        topTypes: [],
        busiestHours: [],
        totalCopyEvents: 0
    )
}

enum ClipboardUsageStatsService {
    private static let dayRange = 14
    private static let topLimit = 8

    @MainActor
    static func compute(container: ModelContainer, calendar: Calendar = .current) -> ClipboardUsageStats {
        let context = ModelContext(container)
        guard let items = try? context.fetch(FetchDescriptor<ClipboardItem>()) else {
            return .empty
        }

        let now = Date.now
        guard let rangeStart = calendar.date(
            byAdding: .day,
            value: -(dayRange - 1),
            to: calendar.startOfDay(for: now)
        ) else {
            return .empty
        }

        var dayBuckets: [Date: Int] = [:]
        for offset in 0..<dayRange {
            if let d = calendar.date(byAdding: .day, value: offset, to: rangeStart) {
                dayBuckets[calendar.startOfDay(for: d)] = 0
            }
        }

        var appCounts: [String: Int] = [:]
        var typeCounts: [String: Int] = [:]
        var hourCounts = Array(repeating: 0, count: 24)
        var totalEvents = 0

        for item in items {
            let events: [ClipboardCopyEvent]
            if item.copyEvents.isEmpty {
                events = [ClipboardCopyEvent(
                    copiedAt: item.effectiveLastCopiedAt,
                    sourceAppBundleID: item.sourceAppBundleID,
                    sourceAppName: item.sourceAppName
                )]
            } else {
                events = item.copyEvents
            }

            for event in events {
                totalEvents += 1
                let day = calendar.startOfDay(for: event.copiedAt)
                if day >= rangeStart {
                    dayBuckets[day, default: 0] += 1
                }

                let app = event.sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines)
                let appKey = (app?.isEmpty == false) ? app! : "Unknown"
                appCounts[appKey, default: 0] += 1

                let hour = calendar.component(.hour, from: event.copiedAt)
                if hour >= 0, hour < 24 { hourCounts[hour] += 1 }
            }

            typeCounts[item.contentType.displayName, default: 0] += max(item.effectiveCopyCount, 1)
        }

        let copiesPerDay = dayBuckets.keys.sorted().map {
            ClipboardUsageStats.DayCount(day: $0, count: dayBuckets[$0] ?? 0)
        }

        let topApps = appCounts
            .sorted { $0.value > $1.value }
            .prefix(topLimit)
            .map { ClipboardUsageStats.NamedCount(name: $0.key, count: $0.value) }

        let topTypes = typeCounts
            .sorted { $0.value > $1.value }
            .prefix(topLimit)
            .map { ClipboardUsageStats.NamedCount(name: $0.key, count: $0.value) }

        let busiestHours = hourCounts.enumerated()
            .map { ClipboardUsageStats.HourCount(hour: $0.offset, count: $0.element) }

        return ClipboardUsageStats(
            copiesPerDay: copiesPerDay,
            topApps: topApps,
            topTypes: topTypes,
            busiestHours: busiestHours,
            totalCopyEvents: totalEvents
        )
    }
}
