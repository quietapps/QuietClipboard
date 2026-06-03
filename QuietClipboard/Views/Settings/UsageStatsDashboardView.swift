import SwiftUI
import Charts

struct UsageStatsDashboardView: View {
    let stats: ClipboardUsageStats
    var isLoading: Bool = false

    private var maxDayCount: Int {
        stats.copiesPerDay.map(\.count).max() ?? 1
    }

    private var maxAppCount: Int {
        stats.topApps.map(\.count).max() ?? 1
    }

    private var maxTypeCount: Int {
        stats.topTypes.map(\.count).max() ?? 1
    }

    private var maxHourCount: Int {
        stats.busiestHours.map(\.count).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isLoading {
                ProgressView("Loading usage…")
                    .frame(maxWidth: .infinity)
            } else if stats.totalCopyEvents == 0 {
                ContentUnavailableView(
                    "No usage data yet",
                    systemImage: "chart.bar",
                    description: Text("Copy something to see activity charts.")
                )
                .frame(minHeight: 120)
            } else {
                copiesPerDaySection
                topAppsSection
                topTypesSection
                busiestHoursSection
            }
        }
        .padding(.vertical, 4)
    }

    private var copiesPerDaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Copies per day", systemImage: "calendar")
                .font(.subheadline.bold())
            Chart(stats.copiesPerDay) { point in
                BarMark(
                    x: .value("Day", point.day, unit: .day),
                    y: .value("Copies", point.count)
                )
                .foregroundStyle(Color.accentColor.gradient)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 140)
        }
    }

    private var topAppsSection: some View {
        rankedBars(
            title: "Top apps",
            systemImage: "app.badge",
            items: stats.topApps,
            maxCount: maxAppCount
        )
    }

    private var topTypesSection: some View {
        rankedBars(
            title: "Top types",
            systemImage: "square.grid.2x2",
            items: stats.topTypes,
            maxCount: maxTypeCount
        )
    }

    private var busiestHoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Busiest hours", systemImage: "clock")
                .font(.subheadline.bold())
            Chart(stats.busiestHours) { point in
                BarMark(
                    x: .value("Hour", point.hour),
                    y: .value("Copies", point.count)
                )
                .foregroundStyle(Color.orange.gradient)
            }
            .chartXScale(domain: 0...23)
            .chartXAxis {
                AxisMarks(values: hourAxisValues) { value in
                    AxisGridLine()
                    AxisValueLabel(centered: true) {
                        if let hour = value.as(Int.self) {
                            Text(compactHourLabel(hour))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 120)
        }
    }

    /// Every 3 hours keeps 24 bars readable in Settings width.
    private var hourAxisValues: [Int] {
        stride(from: 0, through: 23, by: 3).map { $0 }
    }

    private func rankedBars(
        title: String,
        systemImage: String,
        items: [ClipboardUsageStats.NamedCount],
        maxCount: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.bold())
            if items.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(items) { row in
                        HStack(spacing: 8) {
                            Text(row.name)
                                .font(.caption)
                                .lineLimit(1)
                                .frame(width: 100, alignment: .leading)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.35))
                                    .frame(
                                        width: max(4, geo.size.width * CGFloat(row.count) / CGFloat(max(maxCount, 1)))
                                    )
                            }
                            .frame(height: 8)
                            Text("\(row.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    private func compactHourLabel(_ hour: Int) -> String {
        let h = ((hour % 24) + 24) % 24
        switch h {
        case 0: return "12a"
        case 12: return "12p"
        case 1...11: return "\(h)a"
        default: return "\(h - 12)p"
        }
    }
}
