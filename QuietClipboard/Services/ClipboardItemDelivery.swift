import AppKit
import SwiftData

enum PasteDeliveryMethod: String, CaseIterable, Identifiable, Codable {
    case standardPaste
    case autoType

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standardPaste: return "Paste (⌘V)"
        case .autoType: return "Auto-type keystrokes"
        }
    }
}

@MainActor
enum ClipboardItemDelivery {
    /// Delivers clip to the target app using the user's default paste method.
    static func deliver(
        _ item: ClipboardItem,
        priorApp: NSRunningApplication?,
        context: ModelContext,
        monitor: ClipboardMonitor,
        method: PasteDeliveryMethod? = nil,
        asPlainText: Bool = false
    ) {
        let delivery = method ?? Preferences.pasteDeliveryMethod
        switch delivery {
        case .standardPaste:
            deliverWithPaste(item, priorApp: priorApp, context: context, monitor: monitor, asPlainText: asPlainText)
        case .autoType:
            if let text = PasteSimulator.plainText(from: item) {
                deliverWithAutoType(text, item: item, priorApp: priorApp, context: context, monitor: monitor)
            } else {
                deliverWithPaste(item, priorApp: priorApp, context: context, monitor: monitor, asPlainText: asPlainText)
            }
        }
    }

    static func deliverWithPaste(
        _ item: ClipboardItem,
        priorApp: NSRunningApplication?,
        context: ModelContext,
        monitor: ClipboardMonitor,
        asPlainText: Bool = false
    ) {
        // Snapshot the user's current clipboard BEFORE we overwrite it, so we can restore it after.
        let priorArchive = Preferences.restoreClipboardAfterPaste
            ? PasteboardHelper.archiveData(from: .general) : nil

        if asPlainText {
            ClipboardItemUsage.copyPlainTextToPasteboard(item, context: context, monitor: monitor)
        } else {
            ClipboardItemUsage.copyToPasteboard(item, context: context, monitor: monitor)
        }

        PasteSimulator.performPaste(priorApp: priorApp) {
            guard let priorArchive else { return }
            _ = PasteboardHelper.restoreArchive(priorArchive, to: .general)
            monitor.acknowledgeOwnPasteboardWrite()   // don't re-ingest the restored prior clipboard
        }
    }

    static func deliverWithAutoType(
        _ text: String,
        item: ClipboardItem,
        priorApp: NSRunningApplication?,
        context: ModelContext,
        monitor: ClipboardMonitor
    ) {
        ClipboardItemUsage.recordUsage(item, context: context, monitor: monitor)
        PasteSimulator.typeIntoApp(text, priorApp: priorApp)
    }
}
