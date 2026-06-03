import Foundation

enum ClipboardContentType: String, Codable, CaseIterable, Identifiable {
    case text
    case richText
    case markdown
    case image
    case screenshot
    case link
    case file
    case code
    case color
    case svg
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .richText: return "Rich Text"
        case .markdown: return "Markdown"
        case .image: return "Image"
        case .screenshot: return "Screenshot"
        case .link: return "Link"
        case .file: return "File"
        case .code: return "Code"
        case .color: return "Color"
        case .svg: return "SVG"
        case .other: return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "text.alignleft"
        case .richText: return "doc.richtext"
        case .markdown: return "text.document"
        case .image: return "photo"
        case .screenshot: return "camera.viewfinder"
        case .link: return "link"
        case .file: return "doc"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette"
        case .svg: return "square.on.square.dashed"
        case .other: return "questionmark.square"
        }
    }
}
