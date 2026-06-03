import Foundation

struct LibrarySection: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let rows: [LibraryRow]
}

enum LibraryRow: Identifiable {
    case single(ClipboardItem)
    case nearDuplicateGroup(primary: ClipboardItem, siblings: [ClipboardItem])

    var id: String {
        switch self {
        case .single(let item): return item.id.uuidString
        case .nearDuplicateGroup(let primary, _): return "group-\(primary.id.uuidString)"
        }
    }

    var primaryItem: ClipboardItem {
        switch self {
        case .single(let item): return item
        case .nearDuplicateGroup(let primary, _): return primary
        }
    }
}

enum LibraryDisplayGrouping {
    static func sections(
        from items: [ClipboardItem],
        groupBy: LibraryGroupBy,
        categories: [Category],
        collapseNearDuplicates: Bool
    ) -> [LibrarySection] {
        let sorted = items.sorted { $0.effectiveLastCopiedAt > $1.effectiveLastCopiedAt }

        switch groupBy {
        case .none:
            let rows = rows(from: sorted, collapseNearDuplicates: collapseNearDuplicates)
            guard !rows.isEmpty else { return [] }
            return [LibrarySection(id: "all", title: "All", systemImage: "tray.full", rows: rows)]

        case .contentType:
            return ClipboardContentType.allCases.compactMap { type in
                let group = sorted.filter { $0.contentType == type }
                guard !group.isEmpty else { return nil }
                return LibrarySection(
                    id: type.rawValue,
                    title: type.displayName,
                    systemImage: type.systemImage,
                    rows: rows(from: group, collapseNearDuplicates: collapseNearDuplicates)
                )
            }

        case .sourceApp:
            let byApp = Dictionary(grouping: sorted) { $0.sourceAppName ?? "Unknown" }
            return byApp.keys.sorted { lhs, rhs in
                if lhs == "Unknown" { return false }
                if rhs == "Unknown" { return true }
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }.compactMap { appName in
                guard let group = byApp[appName], !group.isEmpty else { return nil }
                return LibrarySection(
                    id: appName,
                    title: appName,
                    systemImage: "app.dashed",
                    rows: rows(from: group, collapseNearDuplicates: collapseNearDuplicates)
                )
            }

        case .category:
            var result: [LibrarySection] = []
            for cat in categories.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                let group = sorted.filter { item in
                    item.categories.contains(where: { $0.id == cat.id })
                }
                guard !group.isEmpty else { continue }
                result.append(LibrarySection(
                    id: cat.id.uuidString,
                    title: cat.name,
                    systemImage: cat.icon,
                    rows: rows(from: group, collapseNearDuplicates: collapseNearDuplicates)
                ))
            }
            let uncategorized = sorted.filter(\.categories.isEmpty)
            if !uncategorized.isEmpty {
                result.append(LibrarySection(
                    id: "uncategorized",
                    title: "Uncategorized",
                    systemImage: "folder",
                    rows: rows(from: uncategorized, collapseNearDuplicates: collapseNearDuplicates)
                ))
            }
            return result
        }
    }

    static func rows(from items: [ClipboardItem], collapseNearDuplicates: Bool) -> [LibraryRow] {
        guard collapseNearDuplicates else {
            return items.map { .single($0) }
        }

        var consumed = Set<UUID>()
        var result: [LibraryRow] = []

        for item in items {
            if consumed.contains(item.id) { continue }
            guard let groupID = item.duplicateGroupID else {
                result.append(.single(item))
                consumed.insert(item.id)
                continue
            }

            let members = items.filter {
                $0.duplicateGroupID == groupID || $0.id == groupID
            }
            let sorted = members.sorted { $0.effectiveLastCopiedAt > $1.effectiveLastCopiedAt }
            guard let primary = sorted.first else { continue }
            let siblings = Array(sorted.dropFirst())
            if siblings.isEmpty {
                result.append(.single(primary))
            } else {
                result.append(.nearDuplicateGroup(primary: primary, siblings: siblings))
            }
            for m in members { consumed.insert(m.id) }
        }

        return result
    }
}
