import Foundation
import SwiftUI

enum LibrarySelection: Hashable {
    case history
    case favorites
    case pinned
    case screenshots
    case timeline
    case category(UUID)
}

/// How clips are sectioned in grid/list (categories use sidebar + this mode).
enum LibraryGroupBy: String, CaseIterable, Identifiable {
    case contentType = "Type"
    case sourceApp = "App"
    case category = "Category"
    case none = "None"

    var id: String { rawValue }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case dateDesc = "Newest"
    case dateAsc = "Oldest"
    case type = "Type"
    case size = "Size"
    case app = "App"
    var id: String { rawValue }
}

enum LibraryView: String, CaseIterable, Identifiable {
    case grid, list, timeline
    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        case .timeline: return "clock"
        }
    }
}

final class LibraryState: ObservableObject {
    @Published var selection: LibrarySelection = .history
    @Published var search: String = ""
    @Published var typeFilter: ClipboardContentType? = nil
    @Published var appFilter: String? = nil
    @Published var groupBy: LibraryGroupBy = .contentType
    @Published var sort: LibrarySort = .dateDesc
    @Published var view: LibraryView = .grid
    @Published var selectedItemID: UUID? = nil
    @Published var expandedDuplicateGroups: Set<String> = []
    @Published var expandedCopyHistories: Set<UUID> = []
    @Published var showTypeFilterBar: Bool = false
    @Published var showAppFilterBar: Bool = false

    /// Multi-paste queue (⌘-click / ⇧-click). Paste order follows the current filtered list.
    @Published var pasteQueueIDs: Set<UUID> = []
    @Published private(set) var queueAnchorID: UUID?

    var pasteQueueCount: Int { pasteQueueIDs.count }

    func isQueued(_ id: UUID) -> Bool { pasteQueueIDs.contains(id) }

    func queuePosition(for id: UUID, in items: [ClipboardItem]) -> Int? {
        guard pasteQueueIDs.contains(id) else { return nil }
        let ordered = orderedQueueItems(in: items)
        guard let idx = ordered.firstIndex(where: { $0.id == id }) else { return nil }
        return idx + 1
    }

    func orderedQueueItems(in items: [ClipboardItem]) -> [ClipboardItem] {
        items.filter { pasteQueueIDs.contains($0.id) }
    }

    func toggleQueue(_ id: UUID) {
        if pasteQueueIDs.contains(id) {
            pasteQueueIDs.remove(id)
        } else {
            pasteQueueIDs.insert(id)
        }
        queueAnchorID = id
    }

    func extendQueueRange(to id: UUID, in items: [ClipboardItem]) {
        let anchor = queueAnchorID
            ?? items.first(where: { pasteQueueIDs.contains($0.id) })?.id
            ?? id

        guard let anchorIdx = items.firstIndex(where: { $0.id == anchor }),
              let targetIdx = items.firstIndex(where: { $0.id == id }) else {
            toggleQueue(id)
            return
        }

        let lower = min(anchorIdx, targetIdx)
        let upper = max(anchorIdx, targetIdx)
        for idx in lower...upper {
            pasteQueueIDs.insert(items[idx].id)
        }
        queueAnchorID = id
    }

    func clearPasteQueue() {
        pasteQueueIDs = []
        queueAnchorID = nil
    }
}
