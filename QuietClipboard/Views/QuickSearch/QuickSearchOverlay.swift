import SwiftUI
import SwiftData
import AppKit

struct QuickSearchOverlay: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var monitor: ClipboardMonitor
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var allItems: [ClipboardItem]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var search: String = ""
    @State private var typeFilter: ClipboardContentType? = nil
    @State private var favoritesOnly: Bool = false
    @State private var pinnedOnly: Bool = false
    @State private var categoryFilter: UUID? = nil
    @State private var selectedIndex: Int = 0
    @State private var keyboardTick: Int = 0
    @State private var lastMouseLocation: CGPoint = .zero
    @State private var previewWidth: CGFloat = Preferences.quickSearchPreviewWidth
    @State private var previewEnabled: Bool = Preferences.quickSearchPreviewEnabled
    @State private var popupViewMode: PopupViewMode = .list
    @FocusState private var searchFocused: Bool
    @State private var displayItems: [ClipboardItem] = []
    @State private var filterTask: Task<Void, Never>?

    var onPaste: (ClipboardItem) -> Void
    var onDismiss: () -> Void
    var onOpenLibrary: () -> Void
    var onTogglePause: () -> Void
    var onQuit: () -> Void

    private var previewItem: ClipboardItem? {
        displayItems.indices.contains(selectedIndex) ? displayItems[selectedIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    listColumn
                        .frame(maxWidth: .infinity)
                    if previewEnabled {
                        splitter
                        PreviewPane(item: previewItem, coordinator: coordinator)
                            .frame(width: clampedPreviewWidth(geo.size.width))
                    }
                }
            }
            if pinnedOnly {
                Divider()
                PinnedSlotsPanel(
                    items: allItems,
                    selectedItemID: previewItem?.id,
                    onActivate: { item in
                        guard coordinator.shouldProceedWithSensitiveAction(for: item) else { return }
                        onPaste(item)
                    },
                    onAssignSelectionToSlot: { slot in
                        guard let item = previewItem else { return }
                        coordinator.pinned.pin(itemID: item.id, to: slot)
                    }
                )
            }
            Divider()
            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.secondary.opacity(0.25))
        )
        .animation(.easeInOut(duration: 0.15), value: typeFilter)
        .onAppear {
            selectedIndex = 0
            previewEnabled = Preferences.quickSearchPreviewEnabled
            previewWidth = Preferences.quickSearchPreviewWidth
            popupViewMode = Preferences.popupViewMode
            sanitizeActiveFilters()
            refreshDisplayItems()
        }
        .onChange(of: popupViewMode) { _, new in
            Preferences.popupViewMode = new
        }
        .onChange(of: search) { _, _ in
            selectedIndex = 0
            scheduleFilterRefresh()
        }
        .onChange(of: typeFilter) { _, _ in scheduleFilterRefresh() }
        .onChange(of: favoritesOnly) { _, _ in scheduleFilterRefresh() }
        .onChange(of: pinnedOnly) { _, _ in scheduleFilterRefresh() }
        .onChange(of: categoryFilter) { _, _ in scheduleFilterRefresh() }
        .onChange(of: allItems.count) { _, _ in scheduleFilterRefresh() }
        .onReceive(coordinator.objectWillChange) { _ in
            sanitizeActiveFilters()
            scheduleFilterRefresh()
        }
        .task {
            try? await Task.sleep(nanoseconds: 60_000_000)
            searchFocused = true
        }
        .background(KeyHandler(
            onEnter: activate,
            onEscape: onDismiss,
            onUp: {
                selectedIndex = max(0, selectedIndex - 1)
                lastMouseLocation = NSEvent.mouseLocation
                keyboardTick &+= 1
            },
            onDown: {
                selectedIndex = min(displayItems.count - 1, selectedIndex + 1)
                lastMouseLocation = NSEvent.mouseLocation
                keyboardTick &+= 1
            },
            onFavorite: favoriteSelected,
            onDelete: deleteSelected,
            onPin: pinSelected,
            onType: typeSelected
        ))
        .onExitCommand(perform: onDismiss)
    }

    private var listColumn: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                TextField("Search clipboard", text: $search)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($searchFocused)
                    .onSubmit { activate() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
            filterBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            if displayItems.isEmpty {
                emptyResultsState
            } else {
                PopupItemsView(
                    items: displayItems,
                    viewMode: popupViewMode,
                    selectedIndex: selectedIndex,
                    keyboardTick: keyboardTick,
                    onActivate: { onPaste($0) },
                    onTogglePin: { togglePin($0) },
                    onDelete: { deleteItem($0) },
                    onToggleFavorite: { toggleFavorite($0) },
                    onHoverIndex: { idx in
                        guard selectedIndex != idx else { return }
                        let now = NSEvent.mouseLocation
                        if abs(now.x - lastMouseLocation.x) < 1.5,
                           abs(now.y - lastMouseLocation.y) < 1.5 { return }
                        lastMouseLocation = now
                        selectedIndex = idx
                    }
                )
            }
        }
    }

    private var filterBar: some View {
        let enabled = QuickSearchFilterPreferences.enabledFilters
        let showCategories = QuickSearchFilterPreferences.showUserCategories
        return HorizontalScrollBar(barHeight: 34, showsHorizontalScroller: true) {
            HStack(spacing: 6) {
                FilterChip(label: "All", systemImage: "tray",
                           isSelected: typeFilter == nil && !favoritesOnly && !pinnedOnly && categoryFilter == nil) {
                    typeFilter = nil; favoritesOnly = false; pinnedOnly = false; categoryFilter = nil
                    selectedIndex = 0
                }
                FilterChip(label: "Pinned", systemImage: "pin.fill", iconOnly: true, isSelected: pinnedOnly) {
                    pinnedOnly.toggle()
                    if pinnedOnly {
                        favoritesOnly = false
                        typeFilter = nil
                        categoryFilter = nil
                    }
                    selectedIndex = 0
                    scheduleFilterRefresh()
                }
                if enabled.contains(.favorites) {
                    FilterChip(label: "Favorites", systemImage: "star.fill", iconOnly: true, isSelected: favoritesOnly) {
                        favoritesOnly.toggle()
                        if favoritesOnly {
                            pinnedOnly = false
                            typeFilter = nil
                            categoryFilter = nil
                        }
                        selectedIndex = 0
                        scheduleFilterRefresh()
                    }
                }
                ForEach(QuickSearchPopupFilter.allCases.filter {
                    $0 != .favorites && $0 != .pinned && enabled.contains($0)
                }) { filter in
                    if let t = filter.contentType {
                        FilterChip(label: filter.displayName, systemImage: filter.systemImage,
                                   isSelected: typeFilter == t) {
                            typeFilter = (typeFilter == t) ? nil : t
                            favoritesOnly = false
                            pinnedOnly = false
                            selectedIndex = 0
                        }
                    }
                }
                if showCategories, !categories.isEmpty {
                    Rectangle().fill(Color.secondary.opacity(0.25))
                        .frame(width: 1, height: 16)
                    ForEach(categories) { c in
                        FilterChip(label: c.name, systemImage: c.icon,
                                   isSelected: categoryFilter == c.id) {
                            categoryFilter = (categoryFilter == c.id) ? nil : c.id
                            favoritesOnly = false
                            pinnedOnly = false
                            selectedIndex = 0
                        }
                    }
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .clipped()
    }

    private func sanitizeActiveFilters() {
        let enabled = QuickSearchFilterPreferences.enabledFilters
        if favoritesOnly, !enabled.contains(.favorites) {
            favoritesOnly = false
        }
        if let t = typeFilter,
           let chip = QuickSearchPopupFilter.from(contentType: t),
           !enabled.contains(chip) {
            typeFilter = nil
        }
        if categoryFilter != nil, !QuickSearchFilterPreferences.showUserCategories {
            categoryFilter = nil
        }
        selectedIndex = min(selectedIndex, max(0, displayItems.count - 1))
    }

    private var emptyResultsState: some View {
        VStack(spacing: 8) {
            Image(systemName: pinnedOnly ? "pin.slash" : "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            if pinnedOnly {
                Text("No pinned slots")
                    .font(.headline)
                Text("Select a clip, then tap the pin icon or press ⌥P to assign a slot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                Text("No results").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scheduleFilterRefresh() {
        filterTask?.cancel()
        let delay: UInt64 = search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 100_000_000
        filterTask = Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: delay)
            }
            guard !Task.isCancelled else { return }
            refreshDisplayItems()
        }
    }

    private func refreshDisplayItems() {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var items = allItems
        if let t = typeFilter { items = items.filter { $0.contentType == t } }
        if favoritesOnly { items = items.filter(\.isFavorite) }
        if pinnedOnly {
            let ordered = coordinator.pinned.orderedItemIDs()
            items = ordered.compactMap { id in items.first(where: { $0.id == id }) }
        }
        if let cid = categoryFilter {
            items = items.filter { $0.categories.contains { $0.id == cid } }
        }
        let limit = Preferences.quickSearchListLimit
        if !q.isEmpty {
            displayItems = Array(ClipSearchMatcher.ranked(items, query: q).prefix(limit))
        } else {
            displayItems = items
                .sorted { $0.effectiveLastCopiedAt > $1.effectiveLastCopiedAt }
                .prefix(limit)
                .map { $0 }
        }
        selectedIndex = min(selectedIndex, max(0, displayItems.count - 1))
    }

    private func clampedPreviewWidth(_ total: CGFloat) -> CGFloat {
        let minPreview: CGFloat = 240
        let maxPreview = max(minPreview, total - 360)
        return min(max(previewWidth, minPreview), maxPreview)
    }

    private var splitter: some View {
        SplitterHandle(width: $previewWidth, minWidth: 240)
            .frame(width: 8)
    }

    private var bottomBar: some View {
        HStack(spacing: 4) {
            PopupViewModePicker(mode: $popupViewMode)
            BottomBarButton(label: "Library", systemImage: "books.vertical", action: onOpenLibrary)
            BottomBarButton(
                label: monitor.isPaused ? "Resume" : "Pause",
                systemImage: monitor.isPaused ? "play.fill" : "pause.fill",
                action: onTogglePause
            )
            SettingsLink {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape").font(.caption)
                    Text("Settings").font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .pointerCursor()
            .simultaneousGesture(TapGesture().onEnded {
                NSApp.activate(ignoringOtherApps: true)
                onDismiss()
            })
            Spacer()
            Text(bottomBarHint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            BottomBarButton(label: "Quit", systemImage: "power", action: onQuit)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var bottomBarHint: String {
        if pinnedOnly {
            return "Pinned · ⌥P pin · ⌥F fav · ⌥D del · ⌥T type"
        }
        return "⌥P pin · ⌥F fav · ⌥D del · ⌥T type"
    }

    private func activate() {
        guard displayItems.indices.contains(selectedIndex) else { return }
        let item = displayItems[selectedIndex]
        guard coordinator.shouldProceedWithSensitiveAction(for: item) else { return }
        onPaste(item)
    }

    private func typeSelected() {
        guard let item = previewItem,
              PasteSimulator.plainText(from: item) != nil else { return }
        guard coordinator.shouldProceedWithSensitiveAction(for: item) else { return }
        coordinator.typeFromQuickSearch(item)
    }

    private func favoriteSelected() {
        guard let item = previewItem else { return }
        toggleFavorite(item)
    }

    private func deleteSelected() {
        guard let item = previewItem else { return }
        deleteItem(item)
    }

    private func pinSelected() {
        guard let item = previewItem else { return }
        togglePin(item)
    }

    private func togglePin(_ item: ClipboardItem) {
        coordinator.pinned.togglePin(itemID: item.id)
    }

    private func deleteItem(_ item: ClipboardItem) {
        if let index = displayItems.firstIndex(where: { $0.id == item.id }),
           selectedIndex >= index, selectedIndex > 0 {
            selectedIndex -= 1
        }
        coordinator.pinned.unpin(itemID: item.id)
        context.delete(item)
        try? context.save()
        selectedIndex = min(selectedIndex, max(0, displayItems.count - 1))
        scheduleFilterRefresh()
    }

    private func toggleFavorite(_ item: ClipboardItem) {
        item.isFavorite.toggle()
        item.modifiedAt = .now
        try? context.save()
    }
}

private struct BottomBarButton: View {
    let label: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.caption)
                Text(label).font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .pointerCursor()
    }
}

private struct FilterChip: View {
    let label: String
    let systemImage: String
    var iconOnly: Bool = false
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: iconOnly ? 0 : 4) {
                Image(systemName: systemImage)
                    .font(iconOnly ? .body : .caption)
                if !iconOnly {
                    Text(label).font(.caption)
                }
            }
            .padding(.horizontal, iconOnly ? 7 : 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear,
                        in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct PreviewPane: View {
    let item: ClipboardItem?
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        if let item {
            VStack(alignment: .leading, spacing: 12) {
                SensitiveContentGate(item: item) {
                    preview(for: item)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                metadata(for: item)
            }
            .padding(16)
            .environmentObject(coordinator)
        } else {
            VStack {
                Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                Text("Nothing to preview").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func preview(for item: ClipboardItem) -> some View {
        switch item.contentType {
        case .image, .screenshot:
            if let nsImage = NSImage(data: item.content) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else { fallback(item) }
        case .color:
            if let hex = item.colorHex, let c = Color(hex: hex) {
                c.clipShape(RoundedRectangle(cornerRadius: 6))
            } else { fallback(item) }
        case .link:
            LinkPreviewCard(item: item)
        case .richText, .markdown:
            RichContentPreview(item: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .text:
            if RichContentRenderer.previewKind(for: item) == .markdown {
                RichContentPreview(item: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                plainTextPreview(item)
            }
        default:
            plainTextPreview(item)
        }
    }

    private func plainTextPreview(_ item: ClipboardItem) -> some View {
        ScrollView {
            Text(item.textContent ?? item.title ?? "")
                .font(.system(.body, design: item.contentType == .code ? .monospaced : .default))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func fallback(_ item: ClipboardItem) -> some View {
        Image(systemName: item.contentType.systemImage)
            .font(.system(size: 48)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func metadata(for item: ClipboardItem) -> some View {
        if item.isSensitive, !coordinator.isSensitiveRevealed(item.id) {
            Text("Reveal to view metadata and copy.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ClipMetadataView(item: item)
        }
    }
}

struct SplitterHandle: NSViewRepresentable {
    @Binding var width: CGFloat
    let minWidth: CGFloat

    func makeNSView(context: Context) -> SplitterNSView {
        let v = SplitterNSView()
        v.minWidth = minWidth
        v.onChange = { newWidth in width = newWidth }
        v.onCommit = { Preferences.quickSearchPreviewWidth = $0 }
        return v
    }

    func updateNSView(_ nsView: SplitterNSView, context: Context) {
        nsView.minWidth = minWidth
        nsView.currentWidth = width
        nsView.onChange = { newWidth in width = newWidth }
        nsView.onCommit = { Preferences.quickSearchPreviewWidth = $0 }
    }
}

final class SplitterNSView: NSView {
    var minWidth: CGFloat = 240
    var currentWidth: CGFloat = 380
    var onChange: ((CGFloat) -> Void)?
    var onCommit: ((CGFloat) -> Void)?

    private var dragStartLocation: NSPoint = .zero
    private var dragStartWidth: CGFloat = 0
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
            owner: self, userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        dragStartLocation = NSEvent.mouseLocation
        dragStartWidth = currentWidth
    }

    override func mouseDragged(with event: NSEvent) {
        let now = NSEvent.mouseLocation
        let dx = now.x - dragStartLocation.x
        let newWidth = max(minWidth, dragStartWidth - dx)
        currentWidth = newWidth
        onChange?(newWidth)
    }

    override func mouseUp(with event: NSEvent) {
        onCommit?(currentWidth)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.withAlphaComponent(0.6).setFill()
        let line = NSRect(x: bounds.midX - 0.5, y: 0, width: 1, height: bounds.height)
        line.fill()
    }
}

struct KeyHandler: NSViewRepresentable {
    var onEnter: () -> Void
    var onEscape: () -> Void
    var onUp: () -> Void
    var onDown: () -> Void
    var onFavorite: (() -> Void)?
    var onDelete: (() -> Void)?
    var onPin: (() -> Void)?
    var onType: (() -> Void)?

    func makeNSView(context: Context) -> KeyHandlerView {
        let v = KeyHandlerView()
        v.onEnter = onEnter
        v.onEscape = onEscape
        v.onUp = onUp
        v.onDown = onDown
        v.onFavorite = onFavorite
        v.onDelete = onDelete
        v.onPin = onPin
        v.onType = onType
        return v
    }

    func updateNSView(_ nsView: KeyHandlerView, context: Context) {
        nsView.onEnter = onEnter
        nsView.onEscape = onEscape
        nsView.onUp = onUp
        nsView.onDown = onDown
        nsView.onFavorite = onFavorite
        nsView.onDelete = onDelete
        nsView.onPin = onPin
        nsView.onType = onType
    }
}

final class KeyHandlerView: NSView {
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?
    var onUp: (() -> Void)?
    var onDown: (() -> Void)?
    var onFavorite: (() -> Void)?
    var onDelete: (() -> Void)?
    var onPin: (() -> Void)?
    var onType: (() -> Void)?

    private var monitor: Any?

    private static func isOptionOnly(_ event: NSEvent) -> Bool {
        let mask: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
        return event.modifierFlags.intersection(mask) == .option
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if Self.isOptionOnly(event) {
                switch event.keyCode {
                case 3: // F
                    self.onFavorite?(); return nil
                case 2: // D
                    self.onDelete?(); return nil
                case 35: // P
                    self.onPin?(); return nil
                case 17: // T
                    self.onType?(); return nil
                default:
                    break
                }
            }
            switch event.keyCode {
            case 36, 76: // return, keypad enter
                self.onEnter?(); return nil
            case 53: // escape
                self.onEscape?(); return nil
            case 126: // up
                self.onUp?(); return nil
            case 125: // down
                self.onDown?(); return nil
            default: return event
            }
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
