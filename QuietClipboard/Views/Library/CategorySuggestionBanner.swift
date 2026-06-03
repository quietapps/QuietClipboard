import SwiftUI
import SwiftData

struct CategorySuggestionBanner: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Bindable var item: ClipboardItem

    var body: some View {
        let suggestions = item.pendingSuggestions
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Suggested categories", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                ForEach(suggestions) { suggestion in
                    HStack(spacing: 8) {
                        Image(systemName: suggestion.icon)
                            .foregroundStyle(Color(hex: suggestion.color) ?? .accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.name).font(.callout.weight(.medium))
                            Text(suggestion.reason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Apply") {
                            apply(suggestion)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                }

                Button("Dismiss all") {
                    item.clearPendingSuggestions()
                    item.modifiedAt = .now
                    try? context.save()
                }
                .buttonStyle(.link)
                .font(.caption)
            }
            .padding(12)
            .background(Color.accentColor.opacity(0.06))
        }
    }

    private func apply(_ suggestion: CategorySuggestion) {
        let cat: Category
        if let existing = categories.first(where: { $0.name.caseInsensitiveCompare(suggestion.name) == .orderedSame }) {
            cat = existing
        } else {
            cat = Category(
                name: suggestion.name,
                icon: suggestion.icon,
                color: suggestion.color,
                sortOrder: (categories.last?.sortOrder ?? 0) + 1
            )
            context.insert(cat)
        }
        if !item.categories.contains(where: { $0.id == cat.id }) {
            item.categories.append(cat)
        }
        let remaining = item.pendingSuggestions.filter { $0.name != suggestion.name }
        if remaining.isEmpty {
            item.clearPendingSuggestions()
        } else {
            item.setPendingSuggestions(remaining)
        }
        item.modifiedAt = .now
        try? context.save()
    }
}
