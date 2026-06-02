import SwiftUI
import SwiftData
import AppKit

struct MenuBarPopover: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject var monitor: ClipboardMonitor
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var items: [ClipboardItem]
    @State private var search: String = ""

    var filtered: [ClipboardItem] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = Array(items.prefix(150))
        guard !trimmed.isEmpty else { return Array(base.prefix(15)) }
        return base.filter { item in
            (item.textContent?.lowercased().contains(trimmed) ?? false)
                || (item.title?.lowercased().contains(trimmed) ?? false)
                || (item.sourceAppName?.lowercased().contains(trimmed) ?? false)
        }
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
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filtered) { item in
                            ItemRow(item: item) { copy(item) }
                        }
                    }
                    .padding(8)
                }
            }
            Divider()
            footer
        }
        .frame(width: 380, height: 480)
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
            Button {
                monitor.setPaused(!monitor.isPaused)
            } label: {
                Label(monitor.isPaused ? "Resume" : "Pause",
                      systemImage: monitor.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.borderless)
            .pointerCursor()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "library")
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
        PasteboardHelper.write(item, to: .general)
    }

    private func openOrRaiseSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if let win = NSApp.windows.first(where: { isSettingsWindow($0) }) {
            win.makeKeyAndOrderFront(nil)
            return
        }
        openSettings()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let win = NSApp.windows.first(where: { isSettingsWindow($0) }) {
                win.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func isSettingsWindow(_ win: NSWindow) -> Bool {
        let id = win.identifier?.rawValue ?? ""
        if id.lowercased().contains("settings") || id.lowercased().contains("preferences") {
            return true
        }
        let title = win.title.lowercased()
        return title.contains("settings") || title.contains("preferences")
    }
}

private struct ItemRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 10) {
                ClipboardItemPreview(item: item)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title ?? item.textContent ?? "Untitled")
                        .lineLimit(1)
                        .font(.system(.body, design: item.contentType == .code ? .monospaced : .default))
                    HStack(spacing: 6) {
                        Image(systemName: item.contentType.systemImage)
                            .font(.caption2)
                        Text(item.sourceAppName ?? "Unknown")
                            .font(.caption2)
                        Text("·").font(.caption2)
                        Text(DateFormatting.relativeString(from: item.createdAt))
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.001))
        )
        .pointerCursor()
    }
}
