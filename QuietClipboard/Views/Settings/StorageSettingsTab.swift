import SwiftUI
import SwiftData

struct StorageSettingsTab: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var retention: RetentionPeriod = Preferences.retention
    @State private var cleanupAge: CleanupAgeOption = .days7
    @State private var historyCounts = RetentionManager.HistoryCounts(total: 0, favorites: 0)
    @State private var staleCount: Int = 0
    @State private var status: StorageStatusMessage?
    @State private var showClearAllConfirm = false
    @State private var showClearNonFavConfirm = false
    @State private var showAgeCleanupConfirm = false

    private var manager: RetentionManager {
        RetentionManager(container: coordinator.container)
    }

    var body: some View {
        SettingsScrollContent {
            if let status {
                StorageStatusBanner(message: status)
            }

            SettingsCard(
                title: "Automatic retention",
                footer: "Runs daily. Favorites are never removed automatically."
            ) {
                SettingsPickerRow(
                    title: "Auto-delete after",
                    icon: "clock.arrow.circlepath",
                    iconTint: .blue,
                    selection: $retention
                ) {
                    ForEach(RetentionPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .onChange(of: retention) { _, value in
                    Preferences.retention = value
                }
            }

            SettingsCard(
                title: "Manual cleanup",
                footer: "Removes non-favorited clips whose last copy is older than the selected window."
            ) {
                SettingsPickerRow(
                    title: "Older than",
                    icon: "calendar.badge.minus",
                    iconTint: .orange,
                    selection: $cleanupAge
                ) {
                    ForEach(CleanupAgeOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .onChange(of: cleanupAge) { _, _ in
                    refreshStaleCount()
                }

                SettingsInsetDivider()

                SettingsValueRow(title: "Eligible clips", icon: "tray.full", iconTint: .teal) {
                    staleCountLabel
                }

                SettingsInsetDivider()

                HStack {
                    SettingsActionButton(
                        title: "Clean up now",
                        systemImage: "trash",
                        variant: .primary
                    ) {
                        showAgeCleanupConfirm = true
                    }
                    .disabled(staleCount == 0)
                }
                .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                .padding(.vertical, 10)
            }

            SettingsCard(
                title: "Danger zone",
                footer: "Erase entire history includes favorites and cannot be undone."
            ) {
                SettingsActionStack {
                    SettingsActionButton(
                        title: "Clear all non-favorites",
                        systemImage: "star.slash",
                        variant: .destructive
                    ) {
                        showClearNonFavConfirm = true
                    }

                    SettingsActionButton(
                        title: "Erase entire history",
                        systemImage: "trash.fill",
                        variant: .destructive
                    ) {
                        showClearAllConfirm = true
                    }
                }
            }

            SettingsCard(
                title: "Backup",
                footer: "Full history backup as a compressed .qcclips file for safekeeping or moving to another Mac. Import accepts .qcclips and older .json exports."
            ) {
                HStack(alignment: .center, spacing: 10) {
                    SettingsActionButton(
                        title: "Export Backup…",
                        systemImage: "square.and.arrow.up",
                        variant: .secondary
                    ) {
                        exportAction()
                    }
                    .frame(maxWidth: .infinity)

                    SettingsActionButton(
                        title: "Import Backup…",
                        systemImage: "square.and.arrow.down",
                        variant: .secondary
                    ) {
                        importAction()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                .padding(.vertical, 12)
            }
        }
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
                .foregroundStyle(SettingsChrome.secondaryText)
        } else {
            Text("\(staleCount)")
                .fontWeight(.medium)
                .foregroundStyle(.orange)
        }
    }

    private func refreshMetrics() {
        historyCounts = manager.historyCounts()
        refreshStaleCount()
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
        Task { @MainActor in
            do {
                let result = try await ExportImportService.export(container: coordinator.container)
                ExportImportService.presentSavePanel(result.url, itemCount: result.itemCount)
                status = .success("Export ready to save.")
            } catch {
                status = .error("Export failed: \(error.localizedDescription)")
            }
        }
    }

    private func importAction() {
        ExportImportService.presentOpenPanel { url in
            guard let url else { return }
            Task { @MainActor in
                do {
                    let count = try await ExportImportService.importFrom(url, container: coordinator.container)
                    refreshMetrics()
                    status = .success("Imported \(count) clip\(count == 1 ? "" : "s").")
                } catch ExportImportError.importCancelled {
                    status = .info("Import canceled.")
                } catch {
                    // Version-mismatch and truncation paths already surfaced an alert;
                    // the banner keeps the detail visible after it closes.
                    status = .error("Import failed: \(error.localizedDescription)")
                }
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
        case .info: return SettingsChrome.secondaryText
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
                .foregroundStyle(SettingsChrome.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, SettingsChrome.rowHorizontalPadding)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SettingsChrome.groupedBackground, in: RoundedRectangle(cornerRadius: SettingsChrome.groupedCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: SettingsChrome.groupedCornerRadius)
                        .stroke(SettingsChrome.groupedStroke, lineWidth: 1)
                )
    }
}

