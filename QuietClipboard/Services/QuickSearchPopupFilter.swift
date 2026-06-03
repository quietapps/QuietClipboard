import Foundation

/// Filter chips available in the Quick Search popup bar.
enum QuickSearchPopupFilter: String, CaseIterable, Identifiable, Codable {
    case favorites
    case text
    case image
    case link
    case code
    case color
    case file
    case screenshot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .favorites: return "Favorites"
        case .text: return "Text"
        case .image: return "Image"
        case .link: return "Link"
        case .code: return "Code"
        case .color: return "Color"
        case .file: return "File"
        case .screenshot: return "Screenshot"
        }
    }

    var systemImage: String {
        switch self {
        case .favorites: return "star.fill"
        case .text: return ClipboardContentType.text.systemImage
        case .image: return ClipboardContentType.image.systemImage
        case .link: return ClipboardContentType.link.systemImage
        case .code: return ClipboardContentType.code.systemImage
        case .color: return ClipboardContentType.color.systemImage
        case .file: return ClipboardContentType.file.systemImage
        case .screenshot: return ClipboardContentType.screenshot.systemImage
        }
    }

    var contentType: ClipboardContentType? {
        switch self {
        case .favorites: return nil
        case .text: return .text
        case .image: return .image
        case .link: return .link
        case .code: return .code
        case .color: return .color
        case .file: return .file
        case .screenshot: return .screenshot
        }
    }

    static var defaultEnabled: Set<QuickSearchPopupFilter> {
        Set(QuickSearchPopupFilter.allCases)
    }

    static func from(contentType: ClipboardContentType) -> QuickSearchPopupFilter? {
        allCases.first { $0.contentType == contentType }
    }
}

enum QuickSearchFilterPreferences {
    private static let filtersKey = "QC.QSVisibleFilters"
    private static let categoriesKey = "QC.QSShowCategories"

    @MainActor
    static var enabledFilters: Set<QuickSearchPopupFilter> {
        get {
            guard let raw = UserDefaults.standard.array(forKey: filtersKey) as? [String] else {
                return QuickSearchPopupFilter.defaultEnabled
            }
            let parsed = Set(raw.compactMap { QuickSearchPopupFilter(rawValue: $0) })
            return parsed.isEmpty ? QuickSearchPopupFilter.defaultEnabled : parsed
        }
        set {
            UserDefaults.standard.set(newValue.map(\.rawValue), forKey: filtersKey)
        }
    }

    @MainActor
    static var showUserCategories: Bool {
        get {
            if UserDefaults.standard.object(forKey: categoriesKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: categoriesKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: categoriesKey) }
    }

    @MainActor
    static func resetToDefaults() {
        enabledFilters = QuickSearchPopupFilter.defaultEnabled
        showUserCategories = true
    }

    @MainActor
    static func isEnabled(_ filter: QuickSearchPopupFilter) -> Bool {
        enabledFilters.contains(filter)
    }
}
