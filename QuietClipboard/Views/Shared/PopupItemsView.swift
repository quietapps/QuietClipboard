import SwiftUI

struct PopupItemsView: View {
    let items: [ClipboardItem]
    let viewMode: PopupViewMode
    var selectedIndex: Int?
    var keyboardTick: Int = 0
    var scrollResetToken: Int = 0
    /// IDs currently multi-selected. Non-empty enables checkmarks + bulk-action mode.
    var multiSelectedIDs: Set<UUID> = []
    let onActivate: (ClipboardItem) -> Void
    /// Called when a row is clicked with ⌘ or ⇧ held, OR when any plain click
    /// happens while `multiSelectedIDs` is non-empty. `Int` is the row's index.
    var onModifierActivate: ((ClipboardItem, Int, NSEvent.ModifierFlags) -> Void)?
    let onTogglePin: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void
    let onToggleFavorite: (ClipboardItem) -> Void
    var onHoverIndex: ((Int) -> Void)?

    @AppStorage("QC.ClipPreviewStyle") private var styleRaw: String = ClipPreviewStyle.rich.rawValue

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 10)]
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                switch viewMode {
                case .list:
                    listBody
                case .grid:
                    gridBody
                }
            }
            .id(scrollResetToken)
            .onChange(of: keyboardTick) { _, _ in
                scrollSelection(into: proxy)
            }
        }
    }

    private var listBody: some View {
        LazyVStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                row(for: item, at: idx)
            }
        }
        .padding(8)
    }

    private var gridBody: some View {
        LazyVGrid(columns: gridColumns, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                card(for: item, at: idx)
            }
        }
        .padding(10)
    }

    @ViewBuilder
    private func row(for item: ClipboardItem, at idx: Int) -> some View {
        PopupClipRow(
            item: item,
            isSelected: selectedIndex == idx,
            isMultiSelected: multiSelectedIDs.contains(item.id),
            multiSelectionActive: !multiSelectedIDs.isEmpty,
            onActivate: { onActivate(item) },
            onModifierActivate: onModifierActivate.map { handler in
                { flags in handler(item, idx, flags) }
            },
            onTogglePin: { onTogglePin(item) },
            onToggleFavorite: { onToggleFavorite(item) },
            onDelete: { onDelete(item) }
        )
        .id(item.id)
        .onHover { inside in
            guard inside, let onHoverIndex else { return }
            onHoverIndex(idx)
        }
    }

    @ViewBuilder
    private func card(for item: ClipboardItem, at idx: Int) -> some View {
        PopupClipCard(
            item: item,
            isSelected: selectedIndex == idx,
            layout: .gridTile,
            onActivate: { onActivate(item) },
            onTogglePin: { onTogglePin(item) },
            onToggleFavorite: { onToggleFavorite(item) },
            onDelete: { onDelete(item) }
        )
        .frame(maxWidth: .infinity)
        .frame(height: LibraryGridMetrics.popupTileHeight)
        .id(item.id)
        .onHover { inside in
            guard inside, let onHoverIndex else { return }
            onHoverIndex(idx)
        }
    }

    private func scrollSelection(into proxy: ScrollViewProxy) {
        guard let selectedIndex, items.indices.contains(selectedIndex) else { return }
        withAnimation {
            proxy.scrollTo(items[selectedIndex].id, anchor: .center)
        }
    }
}
