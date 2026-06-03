import SwiftUI
import SwiftData

struct StorageSettingsTab: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var retention: RetentionPeriod = Preferences.retention
    @State private var cleanupAge: CleanupAgeOption = .days7
    @State private var usage: Int64 = 0
    @State private var historyCounts = RetentionManager.HistoryCounts(total: 0, favorites: 0)
    @State private var staleCount: Int = 0
    @State private var status: StorageStatusMessage?
    @State private var showClearAllConfirm = false
    @State private var showClearNonFavConfirm = false
    @State private var showAgeCleanupConfirm = false
    @State private var usageStats: ClipboardUsageStats = .empty
    @State private var usageStatsLoading = false

    private var manager: RetentionManager {
        RetentionManager(container: coordinator.container)
    }

    var body: some View {
        Form {
            if let status {
                Section {
                    StorageStatusBanner(message: status)
                }
            }

            Section {
                StorageOverviewCard(
                    usageBytes: usage,
                    counts: historyCounts,
                    onRefresh: refreshMetrics
                )
            }

            Section {
                UsageStatsDashboardView(stats: usageStats, isLoading: usageStatsLoading)
            } header: {
                Label("Usage", systemImage: "chart.bar.fill")
            } footer: {
                Text("Based on copy events from the last 14 days. All processing stays on your Mac.")
            }

            Section {
                Picker("Auto-delete after", selection: $retention) {
                    ForEach(RetentionPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: retention) { _, value in
                    Preferences.retention = value
                }
            } header: {
                Label("Automatic retention", systemImage: "clock.arrow.circlepath")
            } footer: {
                Text("Runs daily. Favorites are never removed automatically.")
            }

            Section {
                Picker("Older than", selection: $cleanupAge) {
                    ForEach(CleanupAgeOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: cleanupAge) { _, _ in
                    refreshStaleCount()
                }

                LabeledContent("Eligible clips") {
                    staleCountLabel
                }

                Button {
                    showAgeCleanupConfirm = true
                } label: {
                    Label("Clean up now", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(staleCount == 0)
            } header: {
                Label("Manual cleanup", systemImage: "slider.horizontal.3")
            } footer: {
                Text("Removes non-favorited clips whose last copy is older than the selected window.")
            }

            Section {
                Button(role: .destructive) {
                    showClearNonFavConfirm = true
                } label: {
                    Label("Clear all non-favorites", systemImage: "star.slash")
                }

                Button(role: .destructive) {
                    showClearAllConfirm = true
                } label: {
                    Label("Erase entire history", systemImage: "trash.fill")
                }
            } header: {
                Label("Danger zone", systemImage: "exclamationmark.triangle")
            } footer: {
                Text("Erase entire history includes favorites and cannot be undone.")
            }

            Section {
                HStack(spacing: 12) {
                    Button {
                        exportAction()
                    } label: {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    Button {
                        importAction()
                    } label: {
                        Label("Import JSON", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
            } header: {
                Label("Backup", systemImage: "externaldrive")
            } footer: {
                Text("Full history export for backup or moving to another Mac.")
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshMetrics() }
        .confirmationDialog("Erase entire history?", isPresented: $showClearAllConfirm) {
            Button("Erase everything", role: .destructive) { performClearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes every clip, including favorites. This cannot be undone.")
        }
        .confirmationDialog("Clear all non-favorites?", isPresented: $showClearNonFavConfirm) {
            Button("Clear", role: .destructive) { performClearNonFavorites() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes \(historyCounts.nonFavorites) non-favorited clip\(historyCounts.nonFavorites == 1 ? "" : "s"). Favorites stay.")
        }
        .confirmationDialog("Clean up old clips?", isPresented: $showAgeCleanupConfirm) {
            Button("Remove \(staleCount) clip\(staleCount == 1 ? "" : "s")", role: .destructive) {
                performAgeCleanup()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \(staleCount) non-favorited clip\(staleCount == 1 ? "" : "s") older than \(cleanupAge.displayName)? Favorites are kept.")
        }
    }

    @ViewBuilder
    private var staleCountLabel: some View {
        if staleCount == 0 {
            Text("None")
                .foregroundStyle(.secondary)
        } else {
            Text("\(staleCount)")
                .fontWeight(.medium)
                .foregroundStyle(.orange)
        }
    }

    private func refreshMetrics() {
        usage = RetentionManager.storageUsage()
        historyCounts = manager.historyCounts()
        refreshStaleCount()
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

    private func refreshStaleCount() {
        staleCount = manager.countOlderThan(cleanupAge)
    }

    private func performAgeCleanup() {
        let removed = manager.clearOlderThan(cleanupAge)
        refreshMetrics()
        if removed == 0 {
            status = .info("No clips were older than \(cleanupAge.displayName).")
        } else {
            status = .success("Removed \(removed) clip\(removed == 1 ? "" : "s") older than \(cleanupAge.displayName).")
        }
    }

    private func performClearNonFavorites() {
        manager.clearNonFavorites()
        refreshMetrics()
        status = .success("Cleared all non-favorited clips.")
    }

    private func performClearAll() {
        manager.clearAll()
        refreshMetrics()
        status = .success("History erased.")
    }

    private func exportAction() {
        do {
            let url = try ExportImportService.export(container: coordinator.container)
            ExportImportService.presentSavePanel(url)
            status = .success("Export ready to save.")
        } catch {
            status = .error("Export failed: \(error.localizedDescription)")
        }
    }

    private func importAction() {
        ExportImportService.presentOpenPanel { url in
            guard let url else { return }
            do {
                let count = try ExportImportService.importFrom(url, container: coordinator.container)
                refreshMetrics()
                status = .success("Imported \(count) clip\(count == 1 ? "" : "s").")
            } catch {
                status = .error("Import failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Presentation

private enum StorageStatusMessage: Equatable {
    case success(String)
    case info(String)
    case error(String)

    var text: String {
        switch self {
        case .success(let s), .info(let s), .error(let s): return s
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .success: return .green
        case .info: return .secondary
        case .error: return .orange
        }
    }
}

private struct StorageStatusBanner: View {
    let message: StorageStatusMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: message.icon)
                .foregroundStyle(message.tint)
                .font(.title3)
            Text(message.text)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

private struct StorageOverviewCard: View {
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
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(usageText)
                        .font(.title2.bold())
                    Text("on disk")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }

            HStack(spacing: 0) {
                statBlock(value: counts.total, label: "Total", icon: "tray.full")
                Divider().frame(height: 36)
                statBlock(value: counts.favorites, label: "Favorites", icon: "star.fill")
                Divider().frame(height: 36)
                statBlock(value: counts.nonFavorites, label: "Other", icon: "doc.on.doc")
            }
        }
        .padding(.vertical, 4)
    }

    private func statBlock(value: Int, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
