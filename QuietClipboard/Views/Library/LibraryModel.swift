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
}
