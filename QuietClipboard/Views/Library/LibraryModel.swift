import Foundation
import SwiftUI

enum LibrarySelection: Hashable {
    case history
    case favorites
    case screenshots
    case category(UUID)
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
    case grid, list
    var id: String { rawValue }
    var systemImage: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
}

final class LibraryState: ObservableObject {
    @Published var selection: LibrarySelection = .history
    @Published var search: String = ""
    @Published var typeFilter: ClipboardContentType? = nil
    @Published var sort: LibrarySort = .dateDesc
    @Published var view: LibraryView = .grid
    @Published var selectedItemID: UUID? = nil
}
