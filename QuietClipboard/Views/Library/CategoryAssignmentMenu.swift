import SwiftUI
import SwiftData

struct CategoryAssignmentMenu: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    let item: ClipboardItem

    var body: some View {
        Menu {
            if allCategories.isEmpty {
                Text("No categories")
            } else {
                ForEach(allCategories) { cat in
                    Button {
                        toggle(cat)
                    } label: {
                        Label(cat.name,
                              systemImage: item.categories.contains(where: { $0.id == cat.id })
                              ? "checkmark.circle.fill"
                              : cat.icon)
                    }
                }
            }
        } label: {
            Label("Categories", systemImage: "folder")
        }
    }

    private func toggle(_ cat: Category) {
        if let idx = item.categories.firstIndex(where: { $0.id == cat.id }) {
            item.categories.remove(at: idx)
        } else {
            item.categories.append(cat)
        }
        item.modifiedAt = .now
        try? context.save()
    }
}
