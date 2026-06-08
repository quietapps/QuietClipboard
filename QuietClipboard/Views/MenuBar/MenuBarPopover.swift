import SwiftUI
import SwiftData
import AppKit

/// Compact menu bar popover (`.window` style): search field + plain text list of recent clips,
/// quick-action footer. Click on a row COPIES the clip to the clipboard — the user pastes
/// themselves with ⌘V. Use Quick Search for one-tap paste-into-prior-app.
struct MenuBarPopover: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var monitor: ClipboardMonitor

    @Query(MenuBarPopover.recentDescriptor) private var recent: [ClipboardItem]
    @State private var search = ""
    @FocusState private var searchFocused: Bool
    @State private var copiedID: UUID?

    /// Bounded fetch — the menu bar surfaces recent clips; full-history search is Quick Search.
    static var recentDescriptor: FetchDescriptor<ClipboardItem> {
        var d = FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        d.fetchLimit = 200
        return d
    }

    private var items: [ClipboardItem] {
        let base = recent.sorted { $0.effectiveLastCopiedAt > $1.effectiveLastCopiedAt }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return Array(base.prefix(30)) }
        return Array(ClipSearchMatcher.ranked(base, query: q).prefix(30))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                            row(item, index: idx)
                            if idx < items.count - 1 {
                                Divider().padding(.leading, 12)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
            Divider()
            footer
        }
        .frame(width: 340, height: 440)
        .onAppear { searchFocused = true }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search clips…", text: $search)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear search")
            }
            if monitor.isPaused {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.orange)
                    .help("Capture paused")
            }
        }
        .padding(10)
    }

    private func row(_ item: ClipboardItem, index: Int) -> some View {
        Button {
            ClipboardItemUsage.copyToPasteboard(item, context: context, monitor: monitor)
            copiedID = item.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if copiedID == item.id { copiedID = nil }
            }
        } label: {
            HStack(spacing: 8) {
                Text(rowText(item))
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if copiedID == item.id {
                    Text("Copied")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if index < 9 {
                    Text("⌃⌘\(index + 1)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .help("Copy to clipboard")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel(item, index: index))
        .accessibilityHint("Copies to the clipboard")
    }

    private func rowAccessibilityLabel(_ item: ClipboardItem, index: Int) -> String {
        var label = "\(item.contentType.displayName): \(rowText(item))"
        if let app = item.sourceAppName { label += ", from \(app)" }
        if index < 9 { label += ", shortcut Control Command \(index + 1)" }
        return label
    }

    private func rowText(_ item: ClipboardItem) -> String {
        if let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return String(title.prefix(80))
        }
        if let text = item.textContent?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            let first = text.split(separator: "\n").first.map(String.init) ?? text
            return String(first.prefix(80))
        }
        switch item.contentType {
        case .image, .screenshot: return "Image"
        case .file: return "File"
        case .color: return item.colorHex ?? "Color"
        default: return item.contentType.displayName
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: search.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text(search.isEmpty ? "No clips yet" : "No matches")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            footerButton("rectangle.stack", help: "Open Library (⌃⌘L)") {
                coordinator.openLibraryWindow()
            }
            footerButton("magnifyingglass", help: "Quick Search (⌃⌘V)") {
                coordinator.openQuickSearch()
            }
            footerButton(monitor.isPaused ? "play.fill" : "pause.fill",
                         help: monitor.isPaused ? "Resume capture" : "Pause capture") {
                monitor.setPaused(!monitor.isPaused)
            }
            Spacer()
            Menu {
                if monitor.isPaused {
                    Button("Resume capture") { monitor.setPaused(false) }
                } else {
                    Menu("Pause capture") {
                        Button("For 10 minutes") { monitor.pause(for: 600) }
                        Button("For 1 hour") { monitor.pause(for: 3_600) }
                        Button("For 3 hours") { monitor.pause(for: 10_800) }
                        Button("Until tomorrow") { monitor.pauseUntilTomorrow() }
                    }
                }
                Divider()
                Menu("Clear History") {
                    Button("Clear All") { clearHistory(keepFavorites: false) }
                    Button("Clear except Favorites") { clearHistory(keepFavorites: true) }
                }
                Button("Welcome Tour…") { coordinator.presentOnboarding(force: true) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("More")
            .accessibilityLabel("More actions")
            footerButton("gearshape", help: "Settings") { openSettings() }
            footerButton("power", help: "Quit Quiet Clipboard") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func footerButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .pointerCursor()
        .help(help)
        .accessibilityLabel(Text(help))
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
        guard let allItems = try? context.fetch(descriptor) else { return }
        for item in allItems {
            if keepFavorites && item.isFavorite { continue }
            coordinator.pinned.unpin(itemID: item.id)
            context.delete(item)
        }
        try? context.save()
    }
}
