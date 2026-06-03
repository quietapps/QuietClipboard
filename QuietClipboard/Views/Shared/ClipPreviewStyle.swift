import Foundation

/// How clip rows show thumbnails in lists (popups, library, timeline).
enum ClipPreviewStyle: String, CaseIterable, Identifiable, Codable {
    case rich
    case compact

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rich: return "Rich previews"
        case .compact: return "Compact (text only)"
        }
    }

    var detail: String {
        switch self {
        case .rich: return "Thumbnails and visual cards"
        case .compact: return "Type icon and text — better for long histories"
        }
    }
}
