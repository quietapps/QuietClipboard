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
    @State private var categoryFilter: UUID? = nil
    @State private var selectedIndex: Int = 0
    @State private var keyboardTick: Int = 0
    @State private var lastMouseLocation: CGPoint = .zero
    @State private var previewWidth: CGFloat = Preferences.quickSearchPreviewWidth
    @State private var previewEnabled: Bool = Preferences.quickSearchPreviewEnabled
    @State private var popupViewMode: PopupViewMode = .list
    @FocusState private var searchFocused: Bool

    var onPaste: (ClipboardItem) -> Void
    var onDismiss: () -> Void
    var onOpenLibrary: () -> Void
    var onTogglePause: () -> Void
    var onQuit: () -> Void

    var filtered: [ClipboardItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var items = allItems
        if let t = typeFilter { items = items.filter { $0.contentType == t } }
        if favoritesOnly { items = items.filter { $0.isFavorite } }
        if let cid = categoryFilter {
            items = items.filter { $0.categories.contains { $0.id == cid } }
        }
        if !q.isEmpty {
            items = items.filter { ClipSearchMatcher.matches($0, query: q) }
        }
        return items
            .sorted { $0.effectiveLastCopiedAt > $1.effectiveLastCopiedAt }
            .prefix(50)
            .map { $0 }
    }

    private var previewItem: ClipboardItem? {
        filtered.indices.contains(selectedIndex) ? filtered[selectedIndex] : nil
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
        }
        .onChange(of: popupViewMode) { _, new in
            Preferences.popupViewMode = new
        }
        .onReceive(coordinator.objectWillChange) { _ in
            sanitizeActiveFilters()
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
                selectedIndex = min(filtered.count - 1, selectedIndex + 1)
                lastMouseLocation = NSEvent.mouseLocation
                keyboardTick &+= 1
            }
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
                    .onChange(of: search) { _, _ in selectedIndex = 0 }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
            filterBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            Divider()

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                    Text("No results").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PopupItemsView(
                    items: filtered,
                    viewMode: popupViewMode,
                    selectedIndex: selectedIndex,
                    keyboardTick: keyboardTick,
                    onActivate: { onPaste($0) },
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
        return HorizontalScrollBar {
            HStack(spacing: 6) {
                FilterChip(label: "All", systemImage: "tray",
                           isSelected: typeFilter == nil && !favoritesOnly && categoryFilter == nil) {
                    typeFilter = nil; favoritesOnly = false; categoryFilter = nil
                    selectedIndex = 0
                }
                if enabled.contains(.favorites) {
                    FilterChip(label: "Favorites", systemImage: "star.fill", isSelected: favoritesOnly) {
                        favoritesOnly.toggle()
                        selectedIndex = 0
                    }
                }
                ForEach(QuickSearchPopupFilter.allCases.filter { $0 != .favorites && enabled.contains($0) }) { filter in
                    if let t = filter.contentType {
                        FilterChip(label: filter.displayName, systemImage: filter.systemImage,
                                   isSelected: typeFilter == t) {
                            typeFilter = (typeFilter == t) ? nil : t
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
        selectedIndex = min(selectedIndex, max(0, filtered.count - 1))
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
            BottomBarButton(label: "Quit", systemImage: "power", action: onQuit)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func activate() {
        guard filtered.indices.contains(selectedIndex) else { return }
        let item = filtered[selectedIndex]
        guard coordinator.shouldProceedWithSensitiveAction(for: item) else { return }
        onPaste(item)
    }

    private func deleteItem(_ item: ClipboardItem) {
        if let index = filtered.firstIndex(where: { $0.id == item.id }),
           selectedIndex >= index, selectedIndex > 0 {
            selectedIndex -= 1
        }
        context.delete(item)
        try? context.save()
        selectedIndex = min(selectedIndex, max(0, filtered.count - 1))
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
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.caption)
                Text(label).font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor.opacity(0.25) : Color.clear,
                        in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pointerCursor()
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
            VStack(alignment: .leading, spacing: 8) {
                StructuredDataBadgeRow(item: item, compact: true)
                ClipMetadataView(item: item)
            }
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

    func makeNSView(context: Context) -> KeyHandlerView {
        let v = KeyHandlerView()
        v.onEnter = onEnter
        v.onEscape = onEscape
        v.onUp = onUp
        v.onDown = onDown
        return v
    }

    func updateNSView(_ nsView: KeyHandlerView, context: Context) {
        nsView.onEnter = onEnter
        nsView.onEscape = onEscape
        nsView.onUp = onUp
        nsView.onDown = onDown
    }
}

final class KeyHandlerView: NSView {
    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?
    var onUp: (() -> Void)?
    var onDown: (() -> Void)?

    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
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
