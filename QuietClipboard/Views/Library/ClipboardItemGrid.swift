import SwiftUI
import SwiftData

struct ClipboardItemGrid: View {
    let sections: [LibrarySection]
    @Binding var selectedID: UUID?
    @Binding var expandedGroups: Set<String>
    @Binding var expandedCopyHistories: Set<UUID>
    var onActivate: (ClipboardItem) -> Void

    let columns = [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(sections) { section in
                    sectionBlock(section)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func sectionBlock(_ section: LibrarySection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(section.title, systemImage: section.systemImage)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(section.rows) { row in
                    rowContent(row)
                }
            }
        }
    }

    @ViewBuilder
    private func rowContent(_ row: LibraryRow) -> some View {
        switch row {
        case .single(let item):
            itemButton(item)
        case .nearDuplicateGroup(let primary, let siblings):
            itemButton(primary)
            nearDuplicateExpander(groupKey: row.id, siblings: siblings)
        }
    }

    private func itemButton(_ item: ClipboardItem) -> some View {
        ClipboardItemCard(
            item: item,
            isSelected: item.id == selectedID,
            layout: .gridTile,
            isCopyHistoryExpanded: false,
            onToggleCopyHistory: nil
        )
        .frame(maxWidth: .infinity)
        .frame(height: LibraryGridMetrics.tileHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedID == item.id { onActivate(item) } else { selectedID = item.id }
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onActivate(item) })
        .contextMenu { ItemContextMenu(item: item) }
        .pointerCursor()
    }

    @ViewBuilder
    private func nearDuplicateExpander(groupKey: String, siblings: [ClipboardItem]) -> some View {
        NearDuplicateExpanderCard(
            siblings: siblings,
            groupKey: groupKey,
            expandedGroups: $expandedGroups,
            gridStyle: true
        )
        .frame(maxWidth: .infinity)
        .frame(height: LibraryGridMetrics.tileHeight)

        if expandedGroups.contains(groupKey) {
            ForEach(siblings) { sibling in
                itemButton(sibling)
            }
        }
    }

    private func toggleCopyHistory(for id: UUID) {
        if expandedCopyHistories.contains(id) {
            expandedCopyHistories.remove(id)
        } else {
            expandedCopyHistories.insert(id)
        }
    }
}

struct ClipboardItemList: View {
    let sections: [LibrarySection]
    @Binding var selectedID: UUID?
    @Binding var expandedGroups: Set<String>
    @Binding var expandedCopyHistories: Set<UUID>
    var onActivate: (ClipboardItem) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(section.title, systemImage: section.systemImage)
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                        ForEach(section.rows) { row in
                            listRow(row)
                        }
                    }
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func listRow(_ row: LibraryRow) -> some View {
        switch row {
        case .single(let item):
            listItemButton(item)
        case .nearDuplicateGroup(let primary, let siblings):
            listItemButton(primary)
            nearDupListFooter(row: row, siblings: siblings)
            if expandedGroups.contains(row.id) {
                ForEach(siblings) { listItemButton($0) }
            }
        }
    }

    private func listItemButton(_ item: ClipboardItem) -> some View {
        ClipboardItemRow(
            item: item,
            isSelected: item.id == selectedID,
            isCopyHistoryExpanded: expandedCopyHistories.contains(item.id),
            onToggleCopyHistory: item.effectiveCopyCount > 1
                ? { toggleCopyHistory(for: item.id) }
                : nil
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedID == item.id { onActivate(item) } else { selectedID = item.id }
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onActivate(item) })
        .contextMenu { ItemContextMenu(item: item) }
        .pointerCursor()
    }

    private func nearDupListFooter(row: LibraryRow, siblings: [ClipboardItem]) -> some View {
        NearDuplicateExpanderCard(
            siblings: siblings,
            groupKey: row.id,
            expandedGroups: $expandedGroups,
            gridStyle: false
        )
        .padding(.leading, 8)
    }

    private func toggleCopyHistory(for id: UUID) {
        if expandedCopyHistories.contains(id) {
            expandedCopyHistories.remove(id)
        } else {
            expandedCopyHistories.insert(id)
        }
    }
}

struct ItemContextMenu: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var monitor: ClipboardMonitor
    let item: ClipboardItem

    private var isRedacted: Bool {
        item.isSensitive && !coordinator.isSensitiveRevealed(item.id)
    }

    var body: some View {
        Button {
            guard coordinator.shouldProceedWithSensitiveAction(for: item) else { return }
            ClipboardItemUsage.copyToPasteboard(item, context: context, monitor: monitor)
        } label: {
            Label(isRedacted ? "Reveal" : "Copy", systemImage: isRedacted ? "lock.open" : "doc.on.doc")
        }

        Button {
            item.isFavorite.toggle()
            item.modifiedAt = .now
            try? context.save()
        } label: {
            Label(item.isFavorite ? "Unfavorite" : "Favorite",
                  systemImage: item.isFavorite ? "star.slash" : "star")
        }

        PinnedSlotAssignmentMenu(item: item)

        CategoryAssignmentMenu(item: item)

        if !isRedacted, RichContentRenderer.canExportMarkdown(item) {
            Button {
                ClipExportService.presentSavePanel(for: item, format: .markdown)
            } label: { Label("Export as Markdown…", systemImage: "doc.text") }
        }
        if !isRedacted, RichContentRenderer.canExportRTF(item) {
            Button {
                ClipExportService.presentSavePanel(for: item, format: .rtf)
            } label: { Label("Export as RTF…", systemImage: "doc.richtext") }
        }

        Divider()

        Button(role: .destructive) {
            coordinator.pinned.unpin(itemID: item.id)
            context.delete(item)
            try? context.save()
        } label: { Label("Delete", systemImage: "trash") }
    }
}
