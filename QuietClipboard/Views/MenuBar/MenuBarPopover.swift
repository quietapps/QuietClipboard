import SwiftUI
import SwiftData
import AppKit

struct MenuBarPopover: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var monitor: ClipboardMonitor
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var items: [ClipboardItem]
    @State private var search: String = ""
    @State private var popupViewMode: PopupViewMode = .list

    var filtered: [ClipboardItem] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = items.sorted { $0.effectiveLastCopiedAt > $1.effectiveLastCopiedAt }
        let limited = Array(base.prefix(150))
        guard !trimmed.isEmpty else { return Array(limited.prefix(15)) }
        return limited.filter { ClipSearchMatcher.matches($0, query: trimmed) }
        .prefix(15)
        .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if filtered.isEmpty {
                emptyState
            } else {
                PopupItemsView(
                    items: filtered,
                    viewMode: popupViewMode,
                    onActivate: { copy($0) },
                    onDelete: { deleteItem($0) },
                    onToggleFavorite: { toggleFavorite($0) }
                )
            }
            Divider()
            footer
        }
        .frame(width: 380, height: 480)
        .onAppear { popupViewMode = Preferences.popupViewMode }
        .onChange(of: popupViewMode) { _, new in Preferences.popupViewMode = new }
    }

    private var header: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clips", text: $search)
                .textFieldStyle(.plain)
        }
        .padding(10)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(items.isEmpty ? "No clips yet" : "No matches")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            PopupViewModePicker(mode: $popupViewMode)

            Button {
                monitor.setPaused(!monitor.isPaused)
            } label: {
                Label(monitor.isPaused ? "Resume" : "Pause",
                      systemImage: monitor.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.borderless)
            .pointerCursor()

            Button {
                coordinator.openLibraryWindow()
            } label: {
                Label("Library", systemImage: "tray.full")
            }
            .buttonStyle(.borderless)
            .pointerCursor()

            Spacer()

            Button {
                openOrRaiseSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .pointerCursor()

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .pointerCursor()
        }
        .padding(8)
    }

    private func copy(_ item: ClipboardItem) {
        guard coordinator.shouldProceedWithSensitiveAction(for: item) else { return }
        ClipboardItemUsage.copyToPasteboard(item, context: context, monitor: monitor)
    }

    private func deleteItem(_ item: ClipboardItem) {
        context.delete(item)
        try? context.save()
    }

    private func toggleFavorite(_ item: ClipboardItem) {
        item.isFavorite.toggle()
        item.modifiedAt = .now
        try? context.save()
    }

    private func openOrRaiseSettings() {
        SettingsWindowOpener.open(openSettings: openSettings)
    }
}
