import Foundation

/// Parent groups for capture settings (Settings → Capture → Content Types).
enum CaptureContentGroup: String, CaseIterable, Identifiable, Codable {
    case text
    case media
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .media: return "Media"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .media: return "photo.on.rectangle.angled"
        case .other: return "ellipsis.circle"
        }
    }

    var summary: String {
        switch self {
        case .text:
            return "Plain text, rich text, markdown, links, code, and colors"
        case .media:
            return "Files, images, SVG, and screenshots"
        case .other:
            return "Unclassified clipboard content"
        }
    }

    var contentTypes: [ClipboardContentType] {
        switch self {
        case .text:
            return [.text, .richText, .markdown, .link, .code, .color]
        case .media:
            return [.file, .image, .svg, .screenshot]
        case .other:
            return [.other]
        }
    }

    static func group(for type: ClipboardContentType) -> CaptureContentGroup {
        for group in allCases where group.contentTypes.contains(type) {
            return group
        }
        return .other
    }
}

extension ClipboardContentType {
    var captureGroup: CaptureContentGroup {
        CaptureContentGroup.group(for: self)
    }
}
