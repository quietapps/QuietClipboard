import AppKit
import SwiftData

enum MultiPasteDelimiter: String, CaseIterable, Identifiable, Codable {
    case newline
    case doubleNewline
    case space
    case comma
    case tab
    case semicolon
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newline: return "New line"
        case .doubleNewline: return "Blank line"
        case .space: return "Space"
        case .comma: return "Comma"
        case .tab: return "Tab"
        case .semicolon: return "Semicolon"
        case .custom: return "Custom"
        }
    }

    @MainActor
    func separatorString() -> String {
        switch self {
        case .newline: return "\n"
        case .doubleNewline: return "\n\n"
        case .space: return " "
        case .comma: return ", "
        case .tab: return "\t"
        case .semicolon: return "; "
        case .custom:
            let raw = Preferences.multiPasteCustomDelimiter
            return raw.isEmpty ? "\n" : raw
        }
    }
}

@MainActor
enum MultiPasteService {
    /// Plain-text segment for joining clips (falls back to title / URL / type label when needed).
    static func textSegment(for item: ClipboardItem) -> String? {
        if let text = PasteSimulator.plainText(from: item)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }
        if let link = item.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           item.contentType == .link, !link.isEmpty {
            return link
        }
        if let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        switch item.contentType {
        case .image, .screenshot:
            return "[Image]"
        case .file:
            return item.title ?? "[File]"
        case .color:
            return item.colorHex ?? "[Color]"
        default:
            return nil
        }
    }

    static func combinedText(from items: [ClipboardItem], delimiter: String) -> String? {
        let parts = items.compactMap { textSegment(for: $0) }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: delimiter)
    }

    static func deliver(
        items: [ClipboardItem],
        delimiter: String,
        priorApp: NSRunningApplication?,
        context: ModelContext,
        monitor: ClipboardMonitor,
        method: PasteDeliveryMethod? = nil,
        sensitiveGate: (ClipboardItem) -> Bool
    ) {
        guard items.count >= 2 else { return }
        for item in items {
            guard sensitiveGate(item) else { return }
        }
        guard let combined = combinedText(from: items, delimiter: delimiter) else { return }

        let delivery = method ?? Preferences.pasteDeliveryMethod
        switch delivery {
        case .standardPaste:
            let priorArchive = Preferences.restoreClipboardAfterPaste
                ? PasteboardHelper.archiveData(from: .general) : nil
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(combined, forType: .string)
            monitor.acknowledgeOwnPasteboardWrite()   // hash of the combined text, so it isn't re-ingested
            for item in items {
                ClipboardItemUsage.recordUsage(item, context: context, monitor: monitor)
            }
            PasteSimulator.performPaste(priorApp: priorApp) {
                guard let priorArchive else { return }
                _ = PasteboardHelper.restoreArchive(priorArchive, to: .general)
                monitor.acknowledgeOwnPasteboardWrite()
            }
        case .autoType:
            for item in items {
                ClipboardItemUsage.recordUsage(item, context: context, monitor: monitor)
            }
            PasteSimulator.typeIntoApp(combined, priorApp: priorApp)
        }
    }
}
