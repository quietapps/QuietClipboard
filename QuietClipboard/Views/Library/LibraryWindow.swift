import SwiftUI
import SwiftData
import AppKit

struct LibraryWindow: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var monitor: ClipboardMonitor
    @StateObject private var state = LibraryState()
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var allItems: [ClipboardItem]
    @Query private var categories: [Category]

    var filtered: [ClipboardItem] {
        var items = allItems

        switch state.selection {
        case .history, .timeline:
            break
        case .favorites:
            items = items.filter(\.isFavorite)
        case .pinned:
            let ordered = coordinator.pinned.orderedItemIDs()
            items = ordered.compactMap { id in allItems.first(where: { $0.id == id }) }
        case .screenshots:
            items = items.filter { $0.contentType == .image || $0.contentType == .screenshot }
        case .category(let id):
            items = items.filter { item in item.categories.contains(where: { $0.id == id }) }
        }

        if let t = state.typeFilter {
            items = items.filter { $0.contentType == t }
        }

        let q = state.search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            return ClipSearchMatcher.ranked(items, query: q)
        }

        switch state.sort {
        case .dateDesc:
            items.sort { $0.effectiveLastCopiedAt > $1.effectiveLastCopiedAt }
        case .dateAsc:
            items.sort { $0.effectiveLastCopiedAt < $1.effectiveLastCopiedAt }
        case .type:
            items.sort { $0.contentType.rawValue < $1.contentType.rawValue }
        case .size:
            items.sort { ($0.fileSize ?? 0) > ($1.fileSize ?? 0) }
        case .app:
            items.sort { ($0.sourceAppName ?? "") < ($1.sourceAppName ?? "") }
        }

        return items
    }

    var displaySections: [LibrarySection] {
        LibraryDisplayGrouping.sections(
            from: filtered,
            groupBy: state.groupBy,
            categories: categories,
            collapseNearDuplicates: Preferences.collapseDuplicates
        )
    }

    var selectedItem: ClipboardItem? {
        guard let id = state.selectedItemID else { return nil }
        return allItems.first(where: { $0.id == id })
    }

    private func copyFromLibrary(_ item: ClipboardItem) {
        guard coordinator.shouldProceedWithSensitiveAction(for: item) else { return }
        ClipboardItemUsage.copyToPasteboard(item, context: context, monitor: monitor)
    }

    var body: some View {
        NavigationSplitView {
            LibrarySidebar()
                .environmentObject(state)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } content: {
            VStack(spacing: 0) {
                toolbar
                Divider()
                if filtered.isEmpty {
                    emptyState
                } else if state.view == .timeline || state.selection == .timeline {
                    ClipboardTimelineView(
                        items: filtered,
                        selectedID: $state.selectedItemID,
                        onActivate: copyFromLibrary
                    )
                } else if state.view == .grid {
                    ClipboardItemGrid(
                        sections: displaySections,
                        selectedID: $state.selectedItemID,
                        expandedGroups: $state.expandedDuplicateGroups,
                        expandedCopyHistories: $state.expandedCopyHistories,
                        onActivate: copyFromLibrary
                    )
                } else {
                    ClipboardItemList(
                        sections: displaySections,
                        selectedID: $state.selectedItemID,
                        expandedGroups: $state.expandedDuplicateGroups,
                        expandedCopyHistories: $state.expandedCopyHistories,
                        onActivate: copyFromLibrary
                    )
                }
            }
            .navigationSplitViewColumnWidth(min: 360, ideal: 600)
        } detail: {
            if let item = selectedItem {
                ItemDetailView(item: item)
            } else {
                ContentUnavailableView("No selection",
                                       systemImage: "doc.on.clipboard",
                                       description: Text("Select an item to view details."))
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .navigationTitle("Quiet Clipboard")
        .onAppear {
            state.groupBy = Preferences.libraryGroupBy
        }
        .onChange(of: state.selection) { _, new in
            if new == .timeline {
                state.view = .timeline
            } else if state.view == .timeline {
                state.view = .grid
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search", text: $state.search)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: 280)

            Picker("Type", selection: $state.typeFilter) {
                Text("All").tag(ClipboardContentType?.none)
                ForEach(ClipboardContentType.allCases) { t in
                    Label(t.displayName, systemImage: t.systemImage)
                        .tag(ClipboardContentType?.some(t))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 160)

            Picker("Sort", selection: $state.sort) {
                ForEach(LibrarySort.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 130)

            Picker("Group", selection: $state.groupBy) {
                ForEach(LibraryGroupBy.allCases) { g in
                    Text(g.rawValue).tag(g)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 120)
            .onChange(of: state.groupBy) { _, new in
                Preferences.libraryGroupBy = new
            }

            Spacer()

            Picker("View", selection: $state.view) {
                ForEach(LibraryView.allCases) { v in
                    Image(systemName: v.systemImage).tag(v)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: state.view == .timeline ? 120 : 100)
            .labelsHidden()

            AppSettingsLink {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(10)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No clips",
            systemImage: "tray",
            description: Text(state.search.isEmpty ? "Copy something to get started." : "No matches.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
