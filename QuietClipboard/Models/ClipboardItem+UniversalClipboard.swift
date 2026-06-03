import Foundation

extension ClipboardItem {
    var isUniversalClipboardSource: Bool {
        sourceAppBundleID == UniversalClipboardBridge.syntheticBundleID
    }

    /// SF Symbol for Universal Clipboard source row (iPhone vs iPad).
    var universalClipboardSystemImage: String {
        let name = sourceAppName?.lowercased() ?? ""
        if name.contains("ipad") { return "ipad.and.arrow.forward" }
        if name.contains("watch") { return "applewatch.and.arrow.forward" }
        if name.contains("vision") { return "visionpro.and.arrow.forward" }
        return "iphone.and.arrow.forward"
    }
}
