import AppKit

/// Detects and labels clipboard content synced from iPhone/iPad via Universal Clipboard (Handoff).
enum UniversalClipboardBridge {
    static let remoteMarkerType = NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")
    static let syntheticBundleID = "com.apple.universal-clipboard"

    struct Origin: Equatable {
        let bundleID: String
        let displayName: String
    }

    /// When `com.apple.is-remote-clipboard` is present on the general pasteboard.
    static func origin(from pasteboard: NSPasteboard = .general) -> Origin? {
        guard let types = pasteboard.types, types.contains(remoteMarkerType) else { return nil }
        let name = deviceDisplayName(from: pasteboard, types: types) ?? "iPhone/iPad"
        return Origin(bundleID: syntheticBundleID, displayName: name)
    }

    private static func deviceDisplayName(
        from pasteboard: NSPasteboard,
        types: [NSPasteboard.PasteboardType]
    ) -> String? {
        if let name = stringPayload(from: pasteboard, type: remoteMarkerType) {
            if let parsed = parseDeviceName(name) { return parsed }
        }

        for type in types where type.rawValue.hasPrefix("com.apple.") {
            let raw = type.rawValue.lowercased()
            guard raw.contains("handoff") || raw.contains("remote") || raw.contains("device") else { continue }
            if let name = stringPayload(from: pasteboard, type: type), let parsed = parseDeviceName(name) {
                return parsed
            }
        }

        for item in pasteboard.pasteboardItems ?? [] {
            for type in item.types where type.rawValue.hasPrefix("com.apple.") {
                if let name = item.string(forType: type), let parsed = parseDeviceName(name) {
                    return parsed
                }
                if let data = item.data(forType: type),
                   let name = String(data: data, encoding: .utf8),
                   let parsed = parseDeviceName(name) {
                    return parsed
                }
            }
        }

        return nil
    }

    private static func stringPayload(from pasteboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> String? {
        if let s = pasteboard.string(forType: type)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return s
        }
        if let data = pasteboard.data(forType: type),
           let s = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return s
        }
        return nil
    }

    /// Maps Handoff / system device strings to a short history label.
    static func parseDeviceName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count < 80 else { return nil }
        let lower = trimmed.lowercased()
        if lower.contains("ipad") { return "iPad" }
        if lower.contains("iphone") { return "iPhone" }
        if lower.contains("watch") { return "Apple Watch" }
        if lower.contains("vision") { return "Apple Vision" }
        if lower.contains("mac") { return nil }
        if !lower.contains("://"), !lower.contains(".plist") {
            return trimmed
        }
        return nil
    }
}
