import SwiftUI
import SwiftData

struct StatisticsSettingsTab: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var usage: Int64 = 0
    @State private var historyCounts = RetentionManager.HistoryCounts(total: 0, favorites: 0)
    @State private var usageStats: ClipboardUsageStats = .empty
    @State private var usageStatsLoading = false

    private var manager: RetentionManager {
        RetentionManager(container: coordinator.container)
    }

    var body: some View {
        SettingsScrollContent {
            SettingsCard(title: "Storage overview", systemImage: "internaldrive") {
                StorageOverviewCard(
                    usageBytes: usage,
                    counts: historyCounts,
                    onRefresh: refreshAll
                )
            }

            SettingsCard(
                title: "Usage",
                systemImage: "chart.bar.fill",
                footer: "Based on copy events from the last 14 days. All processing stays on your Mac."
            ) {
                UsageStatsDashboardView(stats: usageStats, isLoading: usageStatsLoading)
            }
        }
        .onAppear { refreshAll() }
    }

    private func refreshAll() {
        usage = RetentionManager.storageUsage()
        historyCounts = manager.historyCounts()
        refreshUsageStats()
    }

    private func refreshUsageStats() {
        usageStatsLoading = true
        let container = coordinator.container
        Task { @MainActor in
            usageStats = ClipboardUsageStatsService.compute(container: container)
            usageStatsLoading = false
        }
    }
}

// MARK: - Overview card (Statistics)

struct StorageOverviewCard: View {
    let usageBytes: Int64
    let counts: RetentionManager.HistoryCounts
    let onRefresh: () -> Void

    private var usageText: String {
        ByteCountFormatter.string(fromByteCount: usageBytes, countStyle: .file)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: "internaldrive")
                    .font(.title2)
                    .foregroundStyle(SettingsChrome.primaryText.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(SettingsChrome.controlFill, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(usageText)
                        .font(.title2.bold())
                        .foregroundStyle(SettingsChrome.primaryText)
                    Text("on disk")
                        .font(.caption)
                        .foregroundStyle(SettingsChrome.secondaryText)
                }

                Spacer()

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(SettingsChrome.secondaryText)
                }
                .buttonStyle(.borderless)
                .pointerCursor()
                .help("Refresh")
            }

            HStack(spacing: 0) {
                statBlock(value: counts.total, label: "Total", icon: "tray.full")
                storageStatDivider
                statBlock(value: counts.favorites, label: "Favorites", icon: "star.fill")
                storageStatDivider
                statBlock(value: counts.nonFavorites, label: "Other", icon: "doc.on.doc")
            }
        }
    }

    private var storageStatDivider: some View {
        Rectangle()
            .fill(SettingsChrome.divider)
            .frame(width: 1, height: 36)
    }

    private func statBlock(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(SettingsChrome.secondaryText)
            Text("\(value)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(SettingsChrome.primaryText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(SettingsChrome.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}
