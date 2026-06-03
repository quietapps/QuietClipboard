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
        method: PasteDeliveryMethod? = nil
    ) {
        let delivery = method ?? Preferences.pasteDeliveryMethod
        switch delivery {
        case .standardPaste:
            deliverWithPaste(item, priorApp: priorApp, context: context, monitor: monitor)
        case .autoType:
            if let text = PasteSimulator.plainText(from: item) {
                deliverWithAutoType(text, item: item, priorApp: priorApp, context: context, monitor: monitor)
            } else {
                deliverWithPaste(item, priorApp: priorApp, context: context, monitor: monitor)
            }
        }
    }

    static func deliverWithPaste(
        _ item: ClipboardItem,
        priorApp: NSRunningApplication?,
        context: ModelContext,
        monitor: ClipboardMonitor
    ) {
        ClipboardItemUsage.copyToPasteboard(item, context: context, monitor: monitor)
        PasteSimulator.performPaste(priorApp: priorApp)
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
