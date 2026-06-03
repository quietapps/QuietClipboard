import SwiftUI
import SwiftData
import AppKit

struct MenuBarPopover: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var monitor: ClipboardMonitor
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var allItems: [ClipboardItem]

    private var recentItems: [ClipboardItem] {
        Array(allItems.sorted { $0.effectiveLastCopiedAt > $1.effectiveLastCopiedAt }.prefix(10))
    }

    var body: some View {
        Button("Open Library") {
            coordinator.openLibraryWindow()
        }

        Divider()

        Menu("History") {
            if recentItems.isEmpty {
                Text("No clips yet")
            } else {
                ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                    Button {
                        ClipboardItemUsage.copyToPasteboard(item, context: context, monitor: monitor)
                    } label: {
                        Label {
                            Text(historyLabel(item))
                        } icon: {
                            if let img = appIcon(for: item.sourceAppBundleID) {
                                Image(nsImage: img)
                            } else {
                                Image(systemName: item.contentType.systemImage)
                            }
                        }
                    }
                    .keyboardShortcut(keyEquiv(index), modifiers: [.control, .command])
                }
            }
        }

        Divider()

        Button("Settings") {
            openSettings()
        }

        if monitor.isPaused {
            Button("Resume") {
                monitor.setPaused(false)
            }
        } else {
            Menu("Pause") {
                Button("For 10 minutes")  { monitor.pause(for: 600) }
                Button("For 1 hour")      { monitor.pause(for: 3_600) }
                Button("For 3 hours")     { monitor.pause(for: 10_800) }
                Button("Until tomorrow")  { monitor.pauseUntilTomorrow() }
            }
        }

        Divider()

        Menu("Clear History") {
            Button("Clear All") { clearHistory(keepFavorites: false) }
            Button("Clear except Favorites") { clearHistory(keepFavorites: true) }
        }

        Divider()

        Button("Quit") {
            NSApp.terminate(nil)
        }
    }

    // MARK: – Helpers

    private func historyLabel(_ item: ClipboardItem) -> String {
        if let size = item.fileSize {
            return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
        let raw = item.title ?? item.textContent ?? item.contentType.displayName
        return String(raw.prefix(60))
    }

    private func appIcon(for bundleID: String?) -> NSImage? {
        guard let bundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func keyEquiv(_ index: Int) -> KeyEquivalent {
        let chars: [Character] = ["0","1","2","3","4","5","6","7","8","9"]
        guard index < chars.count else { return "\0" }
        return KeyEquivalent(chars[index])
    }

    private func clearHistory(keepFavorites: Bool) {
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History"
        alert.informativeText = keepFavorites
            ? "Delete all clips except favorites. This cannot be undone."
            : "Delete all clips including favorites. This cannot be undone."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let descriptor = FetchDescriptor<ClipboardItem>()
        guard let items = try? context.fetch(descriptor) else { return }
        for item in items {
            if keepFavorites && item.isFavorite { continue }
            coordinator.pinned.unpin(itemID: item.id)
            context.delete(item)
        }
        try? context.save()
    }
}
