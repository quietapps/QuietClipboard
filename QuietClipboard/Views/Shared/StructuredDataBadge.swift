import SwiftUI

/// Tappable badge for detected email, phone, UUID, dates, etc.
struct StructuredDataBadge: View {
    let match: StructuredDataMatch
    var compact: Bool = false

    var body: some View {
        Menu {
            Button {
                StructuredDataActions.copyNormalized(match)
            } label: {
                Label("Copy \(match.normalized)", systemImage: "doc.on.doc")
            }

            if match.kind.supportsReminder {
                Button {
                    StructuredDataActions.createReminder(from: match)
                } label: {
                    Label("Create Reminder", systemImage: "calendar.badge.plus")
                }
            }

            if match.kind.supportsContact {
                Button {
                    StructuredDataActions.createContact(from: match)
                } label: {
                    Label("Add to Contacts", systemImage: "person.crop.circle.badge.plus")
                }
            }
        } label: {
            HStack(spacing: compact ? 3 : 4) {
                Image(systemName: match.kind.systemImage)
                Text(match.kind.displayName)
                    .font(compact ? .caption2.weight(.medium) : .caption.weight(.medium))
            }
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 3 : 4)
            .background(Color.accentColor.opacity(0.14), in: Capsule())
            .foregroundStyle(.primary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .pointerCursor()
        .help("Copy normalized \(match.kind.displayName.lowercased()) or create Reminder/Contact")
    }
}

struct StructuredDataBadgeRow: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let item: ClipboardItem
    var compact: Bool = false

    private var matches: [StructuredDataMatch] {
        guard !item.isSensitive || coordinator.isSensitiveRevealed(item.id) else { return [] }
        return item.structuredDataMatches
    }

    var body: some View {
        if !matches.isEmpty {
            HStack(spacing: 6) {
                ForEach(matches) { match in
                    StructuredDataBadge(match: match, compact: compact)
                }
            }
        }
    }
}
