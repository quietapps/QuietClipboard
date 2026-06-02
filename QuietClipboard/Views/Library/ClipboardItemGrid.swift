import SwiftUI
import SwiftData

struct ClipboardItemGrid: View {
    let items: [ClipboardItem]
    @Binding var selectedID: UUID?
    var onActivate: (ClipboardItem) -> Void

    let columns = [GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    Button {
                        if selectedID == item.id {
                            onActivate(item)
                        } else {
                            selectedID = item.id
                        }
                    } label: {
                        ClipboardItemCard(item: item, isSelected: item.id == selectedID)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded { onActivate(item) }
                    )
                    .contextMenu { ItemContextMenu(item: item) }
                    .pointerCursor()
                }
            }
            .padding(16)
        }
    }
}

struct ClipboardItemList: View {
    let items: [ClipboardItem]
    @Binding var selectedID: UUID?
    var onActivate: (ClipboardItem) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(items) { item in
                    Button {
                        if selectedID == item.id {
                            onActivate(item)
                        } else {
                            selectedID = item.id
                        }
                    } label: {
                        ClipboardItemRow(item: item, isSelected: item.id == selectedID)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded { onActivate(item) }
                    )
                    .contextMenu { ItemContextMenu(item: item) }
                    .pointerCursor()
                }
            }
            .padding(8)
        }
    }
}

struct ItemContextMenu: View {
    @Environment(\.modelContext) private var context
    let item: ClipboardItem

    var body: some View {
        Button {
            PasteboardHelper.write(item, to: .general)
        } label: { Label("Copy", systemImage: "doc.on.doc") }

        Button {
            item.isFavorite.toggle()
            item.modifiedAt = .now
            try? context.save()
        } label: {
            Label(item.isFavorite ? "Unfavorite" : "Favorite",
                  systemImage: item.isFavorite ? "star.slash" : "star")
        }

        CategoryAssignmentMenu(item: item)

        Divider()

        Button(role: .destructive) {
            context.delete(item)
            try? context.save()
        } label: { Label("Delete", systemImage: "trash") }
    }
}
