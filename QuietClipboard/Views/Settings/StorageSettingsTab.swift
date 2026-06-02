import SwiftUI
import SwiftData

struct StorageSettingsTab: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var retention: RetentionPeriod = Preferences.retention
    @State private var usage: Int64 = 0
    @State private var showClearAllConfirm = false
    @State private var showClearNonFavConfirm = false
    @State private var status: String?

    var body: some View {
        Form {
            Section("Retention") {
                Picker("Keep history", selection: $retention) {
                    ForEach(RetentionPeriod.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .onChange(of: retention) { _, v in
                    Preferences.retention = v
                }
                Text("Favorites are never auto-deleted.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Storage") {
                LabeledContent("Usage", value: ByteCountFormatter.string(fromByteCount: usage, countStyle: .file))
                Button("Refresh") { usage = RetentionManager.storageUsage() }
            }

            Section("Cleanup") {
                Button("Clear non-favorites") { showClearNonFavConfirm = true }
                Button("Clear all history", role: .destructive) { showClearAllConfirm = true }
            }

            Section("Export / Import") {
                Button("Export to JSON…") { exportAction() }
                Button("Import from JSON…") { importAction() }
                if let status {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { usage = RetentionManager.storageUsage() }
        .confirmationDialog("Clear all history?", isPresented: $showClearAllConfirm) {
            Button("Clear all", role: .destructive) {
                RetentionManager(container: coordinator.container).clearAll()
                usage = RetentionManager.storageUsage()
            }
        } message: {
            Text("This deletes everything including favorites.")
        }
        .confirmationDialog("Clear non-favorites?", isPresented: $showClearNonFavConfirm) {
            Button("Clear", role: .destructive) {
                RetentionManager(container: coordinator.container).clearNonFavorites()
                usage = RetentionManager.storageUsage()
            }
        }
    }

    private func exportAction() {
        do {
            let url = try ExportImportService.export(container: coordinator.container)
            ExportImportService.presentSavePanel(url)
            status = "Exported."
        } catch {
            status = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importAction() {
        ExportImportService.presentOpenPanel { url in
            guard let url else { return }
            do {
                let n = try ExportImportService.importFrom(url, container: coordinator.container)
                status = "Imported \(n) items."
                usage = RetentionManager.storageUsage()
            } catch {
                status = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}
