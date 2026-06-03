import Foundation

enum PopupViewMode: String, CaseIterable, Identifiable, Codable {
    case list
    case grid

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}
