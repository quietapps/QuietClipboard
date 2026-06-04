import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// Per-view cache for the Library's ranked search result (reference type so mutating it during a
/// `body` read doesn't invalidate the view). Keyed by the inputs that change the result.
private final class RankCache {
    var key = ""
    var value: [ClipboardItem] = []
}

struct LibraryWindow: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var monitor: ClipboardMonitor
    @StateObject private var state = LibraryState()
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var allItems: [ClipboardItem]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var showNewCategorySheet = false
    @State private var rankCache = RankCache()

    // MARK: – Filtering (preserved from original)

    // Items filtered only by tab selection (no type/app/search filters)
    private var selectionItems: [ClipboardItem] {
        var items = allItems
        switch state.selection {
        case .history, .timeline: break
        case .favorites: items = items.filter(\.isFavorite)
        case .pinned:
            let ordered = coordinator.pinned.orderedItemIDs()
            items = ordered.compactMap { id in allItems.first(where: { $0.id == id }) }
        case .screenshots:
            items = items.filter { $0.contentType == .image || $0.contentType == .screenshot }
        case .category(let id):
            items = items.filter { item in item.categories.contains(where: { $0.id == id }) }
        }
        return items
    }

    // For filter bar pills: type counts from selectionItems
    var typeCounts: [(ClipboardContentType, Int)] {
        let dict = Dictionary(grouping: selectionItems, by: \.contentType)
        return dict.map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }

    // For filter bar pills: app counts from selectionItems
    var appCounts: [(name: String, bundleID: String?, count: Int)] {
        let groups = Dictionary(grouping: selectionItems.filter { $0.sourceAppName != nil },
                                by: { $0.sourceAppName! })
        return groups.map { (name: $0.key, bundleID: $0.value.first?.sourceAppBundleID, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var filtered: [ClipboardItem] {
        var items = selectionItems

        if let t = state.typeFilter {
            items = items.filter { $0.contentType == t }
        }

        if let app = state.appFilter {
            items = items.filter { $0.sourceAppName == app }
        }

        let q = state.search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            // `filtered` is read several times per render; the ranked scan (bounded Levenshtein
            // over the candidate pool) is the dominant cost. Cache it keyed by the inputs that
            // affect the result so a single render — and repeated renders with the same query —
            // recompute at most once.
            let key = "\(q)|\(state.selection)|\(state.typeFilter?.rawValue ?? "")|\(state.appFilter ?? "")|\(allItems.count)|\(items.count)"
            if rankCache.key == key { return rankCache.value }
            let ranked = ClipSearchMatcher.ranked(items, query: q)
            rankCache.key = key
            rankCache.value = ranked
            return ranked
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

    // MARK: – Category name for detail panel

    private var selectedCategoryName: String {
        switch state.selection {
        case .history, .timeline: return "History"
        case .favorites:           return "Favorites"
        case .pinned:              return "Pinned"
        case .screenshots:         return "Screenshots"
        case .category(let id):
            return categories.first(where: { $0.id == id })?.name ?? "Category"
        }
    }

    // MARK: – Actions

    private func copyFromLibrary(_ item: ClipboardItem) {
        guard coordinator.shouldProceedWithSensitiveAction(for: item) else { return }
        ClipboardItemUsage.copyToPasteboard(item, context: context, monitor: monitor)
    }

    private func deleteItem(_ item: ClipboardItem) {
        coordinator.pinned.unpin(itemID: item.id)
        context.delete(item)
        try? context.save()
        if state.selectedItemID == item.id {
            state.selectedItemID = nil
        }
        state.pasteQueueIDs.remove(item.id)
    }

    private func handleItemTap(_ item: ClipboardItem) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) {
            state.extendQueueRange(to: item.id, in: filtered)
            return
        }
        if flags.contains(.command) {
            state.toggleQueue(item.id)
            return
        }
        withAnimation(.spring(duration: 0.22, bounce: 0.08)) {
            if state.selectedItemID == item.id {
                state.selectedItemID = nil
            } else {
                state.selectedItemID = item.id
            }
        }
    }

    private func pasteQueue() {
        let items = state.orderedQueueItems(in: filtered)
        guard items.count >= 2 else { return }
        let delimiter = Preferences.multiPasteDelimiter.separatorString()
        let prior = PasteSimulator.capturedFrontmost()
        MultiPasteService.deliver(
            items: items,
            delimiter: delimiter,
            priorApp: prior,
            context: context,
            monitor: monitor,
            sensitiveGate: { coordinator.shouldProceedWithSensitiveAction(for: $0) }
        )
    }

    private func toggleFavorite(_ item: ClipboardItem) {
        item.isFavorite.toggle()
        item.modifiedAt = .now
        try? context.save()
    }

    // MARK: – Counts for tab bar

    private var historyCount: Int { allItems.count }
    private var favoritesCount: Int { allItems.filter(\.isFavorite).count }
    private var pinnedCount: Int { coordinator.pinned.filledSlotCount() }
    private var screenshotsCount: Int {
        allItems.filter { $0.contentType == .screenshot || $0.contentType == .image }.count
    }

    // MARK: – Body

    var body: some View {
        VStack(spacing: 0) {
            LibraryTopBar(state: state)
            if state.showTypeFilterBar {
                LibraryTypeFilterBar(state: state, typeCounts: typeCounts, total: selectionItems.count)
            }
            if state.showAppFilterBar {
                LibraryAppFilterBar(state: state, appCounts: appCounts, total: selectionItems.count)
            }
            LibraryCategoryTabBar(
                state: state,
                categories: categories,
                historyCount: historyCount,
                favoritesCount: favoritesCount,
                pinnedCount: pinnedCount,
                screenshotsCount: screenshotsCount,
                onAddCategory: { showNewCategorySheet = true }
            )
            Divider()

            ZStack(alignment: .bottom) {
                ZStack(alignment: .trailing) {
                // Grid area — always full width
                Group {
                    if filtered.isEmpty {
                        emptyState
                    } else if state.view == .timeline || state.selection == .timeline {
                        ClipboardTimelineView(
                            items: filtered,
                            libraryState: state,
                            selectedID: $state.selectedItemID,
                            onActivate: copyFromLibrary,
                            onItemTap: handleItemTap
                        )
                    } else if state.view == .grid {
                        libraryGrid
                    } else {
                        ClipboardItemList(
                            sections: displaySections,
                            items: filtered,
                            libraryState: state,
                            selectedID: $state.selectedItemID,
                            expandedGroups: $state.expandedDuplicateGroups,
                            expandedCopyHistories: $state.expandedCopyHistories,
                            onActivate: copyFromLibrary,
                            onItemTap: handleItemTap
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Subtle scrim when detail panel is open
                if selectedItem != nil {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // Detail panel — floats over the grid from the trailing edge
                if let item = selectedItem {
                    LibraryDetailPanel(
                        item: item,
                        categoryName: selectedCategoryName,
                        onClose: { state.selectedItemID = nil },
                        onCopy: { copyFromLibrary(item) }
                    )
                    .frame(width: 360)
                    .shadow(color: .black.opacity(0.25), radius: 20, x: -4, y: 0)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(10)
                }
                }

                if state.pasteQueueCount > 0 {
                    LibraryPasteQueueBar(
                        state: state,
                        orderedItems: state.orderedQueueItems(in: filtered),
                        onPaste: pasteQueue,
                        onClear: { state.clearPasteQueue() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
                }
            }
        }
        .background(.black)
        .frame(minWidth: 840, minHeight: 560)
        .animation(.spring(duration: 0.22, bounce: 0.08), value: state.selectedItemID)
        .animation(.spring(duration: 0.28, bounce: 0.1), value: state.pasteQueueCount)
        .environmentObject(state)
        .onAppear {
            state.groupBy = Preferences.libraryGroupBy
        }
        .onChange(of: state.selection) { _, new in
            if new == .timeline {
                state.view = .timeline
            } else if state.view == .timeline {
                state.view = .grid
            }
            state.selectedItemID = nil
            state.clearPasteQueue()
        }
        .sheet(isPresented: $showNewCategorySheet) {
            LibraryNewCategorySheet { name, icon, color in
                let cat = Category(
                    name: name,
                    icon: icon,
                    color: color,
                    sortOrder: (categories.last?.sortOrder ?? 0) + 1
                )
                context.insert(cat)
                try? context.save()
            }
        }
    }

    // MARK: – Grid area (new adaptive layout)

    private var libraryGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 16)],
                spacing: 16
            ) {
                ForEach(filtered) { item in
                    LibraryCard(
                        item: item,
                        isSelected: item.id == state.selectedItemID,
                        isQueued: state.isQueued(item.id),
                        queuePosition: state.queuePosition(for: item.id, in: filtered),
                        onTap: { handleItemTap(item) },
                        onCopy: { copyFromLibrary(item) },
                        onFavorite: { toggleFavorite(item) },
                        onDelete: { deleteItem(item) }
                    )
                }
            }
            .padding(16)
            .padding(.bottom, state.pasteQueueCount > 0 ? 64 : 0)
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { state.selectedItemID = nil }
            )
        }
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

// MARK: - LibraryTopBar

private struct LibraryTopBar: View {
    @ObservedObject var state: LibraryState

    var body: some View {
        HStack(spacing: 12) {
            // Borderless search field — full width, no box
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.body)
                TextField("Search", text: $state.search)
                    .textFieldStyle(.plain)
                    .font(.body)
                if !state.search.isEmpty {
                    Button { state.search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .pointerCursor()
                }
            }
            .frame(maxWidth: .infinity)

            // Circular icon buttons
            circleButton(
                systemImage: state.selection == .favorites ? "star.fill" : "star",
                active: state.selection == .favorites
            ) {
                state.selection = (state.selection == .favorites) ? .history : .favorites
            }
            .help("Favorites")

            circleButton(
                systemImage: "square.grid.2x2",
                active: state.showTypeFilterBar || state.typeFilter != nil
            ) {
                state.showTypeFilterBar.toggle()
            }
            .help("Filter by type")

            circleButton(
                systemImage: "app.badge",
                active: state.showAppFilterBar || state.appFilter != nil
            ) {
                state.showAppFilterBar.toggle()
            }
            .help("Filter by app")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func circleButton(
        systemImage: String,
        active: Bool,
        tint: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(active ? (tint ?? .black) : .white.opacity(0.75))
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(active ? (tint ?? .white) : Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.borderless)
        .pointerCursor()
    }
}

// MARK: - LibraryCategoryTabBar

private struct LibraryCategoryTabBar: View {
    @ObservedObject var state: LibraryState
    let categories: [Category]

    let historyCount: Int
    let favoritesCount: Int
    let pinnedCount: Int
    let screenshotsCount: Int
    var onAddCategory: () -> Void  // kept for compatibility — not used by inline flow

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var coordinator: AppCoordinator

    @State private var isCreating = false
    @State private var newName = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        FlowLayout(spacing: 6) {
            tabPill(.history,     label: "History",     count: historyCount)
            tabPill(.favorites,   label: "Favorites",   count: favoritesCount, systemImage: "star.fill")
            tabPill(.pinned,      label: "Pinned",      count: pinnedCount,    systemImage: "pin.fill")
            tabPill(.screenshots, label: "Screenshots", count: screenshotsCount)

            ForEach(categories) { cat in
                categoryPill(cat)
            }

            // Inline category creation
            if isCreating {
                HStack(spacing: 0) {
                    TextField("Name", text: $newName)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .focused($fieldFocused)
                        .frame(minWidth: 80)
                        .onSubmit { commitCreate() }
                    Button(action: commitCreate) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .pointerCursor()
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
                .onAppear { fieldFocused = true }
            }

            // + button
            Button {
                newName = ""
                isCreating = true
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
            }
            .buttonStyle(.borderless)
            .pointerCursor()
            .help("New Category")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commitCreate() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { isCreating = false; return }
        let cat = Category(
            name: name, icon: "folder", color: "#5E5CE6",
            sortOrder: (categories.last?.sortOrder ?? 0) + 1
        )
        context.insert(cat)
        try? context.save()
        isCreating = false
        newName = ""
    }

    @ViewBuilder
    private func tabPill(_ sel: LibrarySelection, label: String, count: Int, systemImage: String? = nil) -> some View {
        BuiltInTabPill(
            selection: sel, label: label, count: count,
            isActive: state.selection == sel,
            systemImage: systemImage,
            onTap: { state.selection = sel },
            onDrop: { assignDroppedItems($0, to: sel) }
        )
    }

    @ViewBuilder
    private func categoryPill(_ cat: Category) -> some View {
        CategoryTabPill(
            cat: cat,
            isActive: state.selection == .category(cat.id),
            onTap: { state.selection = .category(cat.id) },
            onDrop: { assignDroppedItems($0, toCategory: cat) },
            onRename: { newName in
                cat.name = newName
                try? context.save()
            },
            onDelete: {
                if state.selection == .category(cat.id) { state.selection = .history }
                context.delete(cat)
                try? context.save()
            }
        )
    }

    // MARK: – Drop helpers

    private func assignDroppedItems(_ itemIDStrings: [String], to selection: LibrarySelection) {
        for idString in itemIDStrings {
            guard let uuid = UUID(uuidString: idString) else { continue }
            let descriptor = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == uuid })
            guard let item = try? context.fetch(descriptor).first else { continue }
            switch selection {
            case .favorites:
                if !item.isFavorite {
                    item.isFavorite = true
                    item.modifiedAt = .now
                }
            case .pinned:
                if !coordinator.pinned.isPinned(uuid) {
                    _ = coordinator.pinned.pin(itemID: uuid)
                }
            default:
                break
            }
        }
        try? context.save()
    }

    private func assignDroppedItems(_ itemIDStrings: [String], toCategory cat: Category) {
        for idString in itemIDStrings {
            guard let uuid = UUID(uuidString: idString) else { continue }
            // Find item in context by iterating allItems (fetched by caller's @Query)
            // We do a fetch here so we don't need to pass allItems down.
            let descriptor = FetchDescriptor<ClipboardItem>(
                predicate: #Predicate { $0.id == uuid }
            )
            if let item = try? context.fetch(descriptor).first {
                if !item.categories.contains(where: { $0.id == cat.id }) {
                    item.categories.append(cat)
                    item.modifiedAt = .now
                }
            }
        }
        try? context.save()
    }
}

// MARK: - BuiltInTabPill (History / Favorites / Pinned / Screenshots with drop state)

private struct BuiltInTabPill: View {
    let selection: LibrarySelection
    let label: String
    let count: Int
    let isActive: Bool
    var systemImage: String? = nil
    var onTap: () -> Void
    var onDrop: ([String]) -> Void

    @State private var isDropTargeted = false

    private var acceptsDrop: Bool {
        selection == .favorites || selection == .pinned
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let icon = systemImage {
                    Image(systemName: icon)
                        .font(.subheadline.weight(isActive ? .semibold : .regular))
                } else {
                    Text(label)
                        .font(.subheadline.weight(isActive ? .semibold : .regular))
                }
                Text("\(count)")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isActive
                                  ? Color.white.opacity(0.25)
                                  : Color(nsColor: .controlBackgroundColor))
                    )
            }
            .foregroundStyle(isActive ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule()
                    .stroke(isDropTargeted ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.borderless)
        .pointerCursor()
        .onDrop(
            of: [UTType(exportedAs: "app.quiet.QuietClipboard.item-id"), .utf8PlainText],
            isTargeted: $isDropTargeted
        ) { providers, _ in
            guard acceptsDrop else { return false }
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier("app.quiet.QuietClipboard.item-id") {
                    provider.loadDataRepresentation(forTypeIdentifier: "app.quiet.QuietClipboard.item-id") { data, _ in
                        if let data, let str = String(data: data, encoding: .utf8), UUID(uuidString: str) != nil {
                            DispatchQueue.main.async { onDrop([str]) }
                        }
                    }
                } else {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier) { data, _ in
                        if let data, let str = String(data: data, encoding: .utf8), UUID(uuidString: str) != nil {
                            DispatchQueue.main.async { onDrop([str]) }
                        }
                    }
                }
            }
            return true
        }
    }
}

// MARK: - CategoryTabPill (category pills with drop targeting state)

private struct CategoryTabPill: View {
    let cat: Category
    let isActive: Bool
    var onTap: () -> Void
    var onDrop: ([String]) -> Void
    var onRename: (String) -> Void
    var onDelete: () -> Void

    @State private var isDropTargeted = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @FocusState private var renameFocused: Bool

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: cat.icon)
                    .font(.caption)
                Text(cat.name)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                Text("\(cat.items.count)")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isActive
                                  ? Color.white.opacity(0.25)
                                  : Color(nsColor: .controlBackgroundColor))
                    )
            }
            .foregroundStyle(isActive ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                Capsule()
                    .stroke(isDropTargeted ? Color.green : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.borderless)
        .pointerCursor()
        .contextMenu {
            Button("Rename") {
                renameText = cat.name
                isRenaming = true
            }
            Divider()
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
        .popover(isPresented: $isRenaming, arrowEdge: .bottom) {
            HStack(spacing: 8) {
                TextField("Name", text: $renameText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .frame(width: 160)
                    .focused($renameFocused)
                    .onSubmit {
                        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { onRename(trimmed) }
                        isRenaming = false
                    }
                Button {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { onRename(trimmed) }
                    isRenaming = false
                } label: {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .pointerCursor()
            }
            .padding(12)
            .onAppear { renameFocused = true }
        }
        .onDrop(
            of: [UTType(exportedAs: "app.quiet.QuietClipboard.item-id"), .utf8PlainText],
            isTargeted: $isDropTargeted
        ) { providers, _ in
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier("app.quiet.QuietClipboard.item-id") {
                    provider.loadDataRepresentation(forTypeIdentifier: "app.quiet.QuietClipboard.item-id") { data, _ in
                        if let data, let str = String(data: data, encoding: .utf8), UUID(uuidString: str) != nil {
                            DispatchQueue.main.async { onDrop([str]) }
                        }
                    }
                } else {
                    provider.loadDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier) { data, _ in
                        if let data, let str = String(data: data, encoding: .utf8), UUID(uuidString: str) != nil {
                            DispatchQueue.main.async { onDrop([str]) }
                        }
                    }
                }
            }
            return true
        }
    }
}

// MARK: - LibraryNewCategorySheet

/// Public duplicate of NewCategorySheet from LibrarySidebar.swift so LibraryWindow
/// can present it without referencing the file-private type.
struct LibraryNewCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    var onSave: (String, String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Category").font(.headline)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    guard !name.isEmpty else { return }
                    onSave(name, "folder", "#5E5CE6")
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0 && rowWidth + spacing + size.width > maxWidth {
                height += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - LibraryTypeFilterBar

struct LibraryTypeFilterBar: View {
    @ObservedObject var state: LibraryState
    let typeCounts: [(ClipboardContentType, Int)]
    let total: Int

    var body: some View {
        FlowLayout(spacing: 6) {
            filterPill(type: nil, label: "All types", count: total)
            ForEach(typeCounts, id: \.0.rawValue) { (type, count) in
                filterPill(type: type, label: type.displayName, count: count)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
    }

    @ViewBuilder
    private func filterPill(type: ClipboardContentType?, label: String, count: Int) -> some View {
        let isActive = state.typeFilter == type
        Button {
            state.typeFilter = type
        } label: {
            HStack(spacing: 4) {
                if let type {
                    Image(systemName: type.systemImage).font(.caption)
                }
                Text(label)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                Text("\(count)")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(isActive ? Color.black.opacity(0.2) : Color.white.opacity(0.1)))
            }
            .foregroundStyle(isActive ? .black : .white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(isActive ? .white : Color.white.opacity(0.12)))
        }
        .buttonStyle(.borderless)
        .pointerCursor()
    }
}

// MARK: - LibraryAppFilterBar

struct LibraryAppFilterBar: View {
    @ObservedObject var state: LibraryState
    let appCounts: [(name: String, bundleID: String?, count: Int)]
    let total: Int

    var body: some View {
        FlowLayout(spacing: 6) {
            appPill(name: nil, bundleID: nil, count: total)
            ForEach(appCounts, id: \.name) { entry in
                appPill(name: entry.name, bundleID: entry.bundleID, count: entry.count)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
    }

    @ViewBuilder
    private func appPill(name: String?, bundleID: String?, count: Int) -> some View {
        let isActive = state.appFilter == name
        Button {
            state.appFilter = name
        } label: {
            HStack(spacing: 4) {
                if let bundleID,
                   let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .frame(width: 13, height: 13)
                }
                Text(name ?? "All apps")
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                Text("\(count)")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(isActive ? Color.black.opacity(0.2) : Color.white.opacity(0.1)))
            }
            .foregroundStyle(isActive ? .black : .white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Capsule().fill(isActive ? .white : Color.white.opacity(0.12)))
        }
        .buttonStyle(.borderless)
        .pointerCursor()
    }
}
