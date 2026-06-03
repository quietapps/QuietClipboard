import SwiftUI
import SwiftData

struct LibrarySidebar: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject var state: LibraryState
    @EnvironmentObject var coordinator: AppCoordinator
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var items: [ClipboardItem]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var newCategoryName: String = ""
    @State private var showingNewCategory = false

    var body: some View {
        List(selection: $state.selection) {
            Section("Library") {
                row(.history, label: "History", icon: "tray.full",
                    count: items.count)
                row(.favorites, label: "Favorites", icon: "star.fill",
                    count: items.filter(\.isFavorite).count)
                row(.pinned, label: "Pinned", icon: "pin.fill",
                    count: coordinator.pinned.filledSlotCount())
                row(.screenshots, label: "Screenshots", icon: "camera.viewfinder",
                    count: items.filter { $0.contentType == .screenshot || $0.contentType == .image }.count)
                row(.timeline, label: "Timeline", icon: "clock",
                    count: items.filter { Calendar.current.isDateInToday($0.effectiveLastCopiedAt) }.count)
            }
            Section {
                ForEach(categories) { cat in
                    row(.category(cat.id), label: cat.name, icon: cat.icon,
                        count: cat.items.count)
                        .swipeActions {
                            Button(role: .destructive) {
                                context.delete(cat)
                                try? context.save()
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                }
                Button {
                    showingNewCategory = true
                } label: {
                    Label("New Category", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } header: {
                Text("Categories")
            }
        }
        .listStyle(.sidebar)
        .sheet(isPresented: $showingNewCategory) {
            NewCategorySheet { name, icon, color in
                let cat = Category(name: name, icon: icon, color: color,
                                   sortOrder: (categories.last?.sortOrder ?? 0) + 1)
                context.insert(cat)
                try? context.save()
            }
        }
    }

    @ViewBuilder
    private func row(_ sel: LibrarySelection, label: String, icon: String, count: Int) -> some View {
        Label {
            HStack {
                Text(label)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        } icon: {
            Image(systemName: icon)
        }
        .tag(sel)
    }
}

private struct NewCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var icon: String = "folder"
    @State private var color: String = "#5E5CE6"
    var onSave: (String, String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Category").font(.headline)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            HStack {
                TextField("SF Symbol", text: $icon).textFieldStyle(.roundedBorder)
                TextField("#RRGGBB", text: $color).textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    guard !name.isEmpty else { return }
                    onSave(name, icon, color)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
