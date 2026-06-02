import SwiftUI
import SwiftData
import AppKit

struct LibraryWindow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openSettings) private var openSettings
    @StateObject private var state = LibraryState()
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var allItems: [ClipboardItem]
    @Query private var categories: [Category]

    var filtered: [ClipboardItem] {
        var items = allItems

        switch state.selection {
        case .history:
            break
        case .favorites:
            items = items.filter(\.isFavorite)
        case .screenshots:
            items = items.filter { $0.contentType == .image || $0.contentType == .screenshot }
        case .category(let id):
            items = items.filter { item in item.categories.contains(where: { $0.id == id }) }
        }

        if let t = state.typeFilter {
            items = items.filter { $0.contentType == t }
        }

        let q = state.search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            items = items.filter { item in
                (item.textContent?.lowercased().contains(q) ?? false)
                    || (item.title?.lowercased().contains(q) ?? false)
                    || (item.ocrText?.lowercased().contains(q) ?? false)
                    || (item.linkPreviewTitle?.lowercased().contains(q) ?? false)
                    || (item.sourceAppName?.lowercased().contains(q) ?? false)
                    || (item.colorHex?.lowercased().contains(q) ?? false)
            }
        }

        switch state.sort {
        case .dateDesc:
            items.sort { $0.createdAt > $1.createdAt }
        case .dateAsc:
            items.sort { $0.createdAt < $1.createdAt }
        case .type:
            items.sort { $0.contentType.rawValue < $1.contentType.rawValue }
        case .size:
            items.sort { ($0.fileSize ?? 0) > ($1.fileSize ?? 0) }
        case .app:
            items.sort { ($0.sourceAppName ?? "") < ($1.sourceAppName ?? "") }
        }

        return items
    }

    var selectedItem: ClipboardItem? {
        guard let id = state.selectedItemID else { return nil }
        return allItems.first(where: { $0.id == id })
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
                } else if state.view == .grid {
                    ClipboardItemGrid(
                        items: filtered,
                        selectedID: $state.selectedItemID,
                        onActivate: { PasteboardHelper.write($0, to: .general) }
                    )
                } else {
                    ClipboardItemList(
                        items: filtered,
                        selectedID: $state.selectedItemID,
                        onActivate: { PasteboardHelper.write($0, to: .general) }
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

            Spacer()

            Picker("View", selection: $state.view) {
                ForEach(LibraryView.allCases) { v in
                    Image(systemName: v.systemImage).tag(v)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
            .labelsHidden()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
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
