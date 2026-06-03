import AppKit
import Foundation
import UniformTypeIdentifiers

enum ClipExportFormat {
    case markdown
    case rtf

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .rtf: return "rtf"
        }
    }

    var contentType: UTType {
        switch self {
        case .markdown: return .plainText
        case .rtf: return .rtf
        }
    }
}

@MainActor
enum ClipExportService {
    static func export(item: ClipboardItem, format: ClipExportFormat) throws -> URL {
        let data: Data
        switch format {
        case .markdown:
            guard let d = RichContentRenderer.markdownData(for: item) else {
                throw ClipExportError.noContent
            }
            data = d
        case .rtf:
            guard let d = RichContentRenderer.rtfData(for: item) else {
                throw ClipExportError.noContent
            }
            data = d
        }

        let filename = suggestedFilename(for: item, fileExtension: format.fileExtension)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func presentSavePanel(for item: ClipboardItem, format: ClipExportFormat) {
        do {
            let tempURL = try export(item: item, format: format)
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.nameFieldStringValue = tempURL.lastPathComponent
            panel.allowedContentTypes = [format.contentType]
            panel.begin { response in
                guard response == .OK, let dest = panel.url else { return }
                do {
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.copyItem(at: tempURL, to: dest)
                } catch {
                    NSLog("Clip export failed: \(error)")
                }
            }
        } catch {
            NSLog("Clip export prepare failed: \(error)")
        }
    }

    private static func suggestedFilename(for item: ClipboardItem, fileExtension ext: String) -> String {
        let raw = item.title
            ?? item.textContent?.split(separator: "\n").first.map(String.init)
            ?? "QuietClipboard-clip"
        let trimmed = String(raw.prefix(80))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.map { ch in
            ch.isLetter || ch.isNumber || ch == "-" || ch == "_" || ch == "." ? ch : "-"
        }
        let base = String(safe).trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        let name = base.isEmpty ? "QuietClipboard-clip" : base
        return "\(name).\(ext)"
    }
}

enum ClipExportError: LocalizedError {
    case noContent

    var errorDescription: String? {
        switch self {
        case .noContent: return "Nothing to export for this clip."
        }
    }
}
