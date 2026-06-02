import SwiftUI
import SwiftData
import AppKit

struct QuickSearchOverlay: View {
    @Environment(\.modelContext) private var context
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
            items = items.filter { item in
                (item.textContent?.lowercased().contains(q) ?? false)
                    || (item.title?.lowercased().contains(q) ?? false)
                    || (item.ocrText?.lowercased().contains(q) ?? false)
                    || (item.linkPreviewTitle?.lowercased().contains(q) ?? false)
                    || (item.sourceAppName?.lowercased().contains(q) ?? false)
                    || (item.colorHex?.lowercased().contains(q) ?? false)
            }
        }
        return Array(items.prefix(50))
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
                        PreviewPane(item: previewItem)
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
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, item in
                                Button {
                                    onPaste(item)
                                } label: {
                                    ResultRow(item: item, isSelected: idx == selectedIndex)
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .pointerCursor()
                                .id(item.id)
                                .onHover { inside in
                                    guard inside, selectedIndex != idx else { return }
                                    let now = NSEvent.mouseLocation
                                    if abs(now.x - lastMouseLocation.x) < 1.5,
                                       abs(now.y - lastMouseLocation.y) < 1.5 { return }
                                    lastMouseLocation = now
                                    selectedIndex = idx
                                }
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: keyboardTick) { _, _ in
                        guard filtered.indices.contains(selectedIndex) else { return }
                        withAnimation { proxy.scrollTo(filtered[selectedIndex].id, anchor: .center) }
                    }
                }
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "All", systemImage: "tray",
                           isSelected: typeFilter == nil && !favoritesOnly && categoryFilter == nil) {
                    typeFilter = nil; favoritesOnly = false; categoryFilter = nil
                }
                FilterChip(label: "Favorites", systemImage: "star.fill", isSelected: favoritesOnly) {
                    favoritesOnly.toggle()
                    selectedIndex = 0
                }
                ForEach([ClipboardContentType.text, .image, .link, .code, .color, .file, .screenshot], id: \.self) { t in
                    FilterChip(label: t.displayName, systemImage: t.systemImage,
                               isSelected: typeFilter == t) {
                        typeFilter = (typeFilter == t) ? nil : t
                        selectedIndex = 0
                    }
                }
                if !categories.isEmpty {
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
            .padding(.horizontal, 2)
        }
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
        onPaste(filtered[selectedIndex])
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

private struct ResultRow: View {
    let item: ClipboardItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ClipboardItemPreview(item: item)
                .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title ?? item.textContent ?? "Untitled")
                    .font(.system(.body, design: item.contentType == .code ? .monospaced : .default))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: item.contentType.systemImage).font(.caption2)
                    Text(item.contentType.displayName).font(.caption2)
                    Text("·").font(.caption2)
                    Text(item.sourceAppName ?? "Unknown").font(.caption2)
                    Text("·").font(.caption2)
                    Text(DateFormatting.relativeString(from: item.createdAt)).font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            if item.isFavorite {
                Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
        )
    }
}

private struct PreviewPane: View {
    let item: ClipboardItem?

    var body: some View {
        if let item {
            VStack(alignment: .leading, spacing: 12) {
                preview(for: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                metadata(for: item)
            }
            .padding(16)
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
            VStack(alignment: .leading, spacing: 8) {
                Text(item.linkPreviewTitle ?? item.title ?? "").font(.headline)
                Text(item.linkPreviewDescription ?? "").font(.caption).foregroundStyle(.secondary)
                Text(item.textContent ?? "").font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                Spacer()
            }
        default:
            ScrollView {
                Text(item.textContent ?? item.title ?? "")
                    .font(.system(.body, design: item.contentType == .code ? .monospaced : .default))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder
    private func fallback(_ item: ClipboardItem) -> some View {
        Image(systemName: item.contentType.systemImage)
            .font(.system(size: 48)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func metadata(for item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Application:").foregroundStyle(.secondary)
                Text(item.sourceAppName ?? "Unknown").bold()
            }
            HStack(spacing: 6) {
                Text("Copied:").foregroundStyle(.secondary)
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            HStack(spacing: 6) {
                Text("Type:").foregroundStyle(.secondary)
                Text(item.contentType.displayName)
            }
        }
        .font(.callout)
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
