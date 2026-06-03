import SwiftUI

struct PopupItemsView: View {
    let items: [ClipboardItem]
    let viewMode: PopupViewMode
    var selectedIndex: Int?
    var keyboardTick: Int = 0
    let onActivate: (ClipboardItem) -> Void
    let onDelete: (ClipboardItem) -> Void
    let onToggleFavorite: (ClipboardItem) -> Void
    var onHoverIndex: ((Int) -> Void)?

    @AppStorage("QC.ClipPreviewStyle") private var styleRaw: String = ClipPreviewStyle.rich.rawValue

    private var gridColumns: [GridItem] {
        let compact = (ClipPreviewStyle(rawValue: styleRaw) ?? .rich) == .compact
        let min: CGFloat = compact ? 108 : 132
        let max: CGFloat = compact ? 140 : 168
        return [GridItem(.adaptive(minimum: min, maximum: max), spacing: 8)]
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
        LazyVGrid(columns: gridColumns, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                card(for: item, at: idx)
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private func row(for item: ClipboardItem, at idx: Int) -> some View {
        PopupClipRow(
            item: item,
            isSelected: selectedIndex == idx,
            onActivate: { onActivate(item) },
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
            onActivate: { onActivate(item) },
            onToggleFavorite: { onToggleFavorite(item) },
            onDelete: { onDelete(item) }
        )
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
