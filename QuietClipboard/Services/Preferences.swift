import Foundation
import SwiftUI
import ServiceManagement

enum SensitiveBehavior: String, CaseIterable, Identifiable, Codable {
    case skip
    case saveHidden
    case saveNormal
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .skip: return "Don't save"
        case .saveHidden: return "Save but hide"
        case .saveNormal: return "Save normally"
        }
    }
}

enum RetentionPeriod: String, CaseIterable, Identifiable, Codable {
    case d7, d15, d30, d90, forever
    var id: String { rawValue }
    var days: Int? {
        switch self {
        case .d7: return 7
        case .d15: return 15
        case .d30: return 30
        case .d90: return 90
        case .forever: return nil
        }
    }
    var displayName: String {
        switch self {
        case .d7: return "7 days"
        case .d15: return "15 days"
        case .d30: return "30 days"
        case .d90: return "90 days"
        case .forever: return "Forever"
        }
    }
}

enum Preferences {
    private static let defaults = UserDefaults.standard

    @MainActor static var sensitiveDetectionEnabled: Bool {
        get { defaults.object(forKey: "QC.SensitiveEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "QC.SensitiveEnabled") }
    }

    @MainActor static var sensitiveBehavior: SensitiveBehavior {
        get {
            guard let raw = defaults.string(forKey: "QC.SensitiveBehavior"),
                  let v = SensitiveBehavior(rawValue: raw) else { return .saveNormal }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: "QC.SensitiveBehavior") }
    }

    @MainActor static var retention: RetentionPeriod {
        get {
            guard let raw = defaults.string(forKey: "QC.Retention"),
                  let v = RetentionPeriod(rawValue: raw) else { return .d30 }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: "QC.Retention") }
    }

    @MainActor static var capturedTypes: Set<ClipboardContentType> {
        get {
            if let raw = defaults.array(forKey: "QC.CapturedTypes") as? [String] {
                return Set(raw.compactMap { ClipboardContentType(rawValue: $0) })
            }
            return Set(ClipboardContentType.allCases)
        }
        set {
            defaults.set(newValue.map(\.rawValue), forKey: "QC.CapturedTypes")
        }
    }

    /// Master switches for capture groups (Text, Media, Other). When off, no types in that group are captured.
    @MainActor static var enabledCaptureGroups: Set<CaptureContentGroup> {
        get {
            // Only an ABSENT key means "never configured" → default to all on. A persisted
            // empty array is a deliberate "everything off" state and must be preserved.
            guard let raw = defaults.array(forKey: "QC.CaptureGroupsEnabled") as? [String] else {
                return Set(CaptureContentGroup.allCases)
            }
            return Set(raw.compactMap { CaptureContentGroup(rawValue: $0) })
        }
        set {
            defaults.set(newValue.map(\.rawValue), forKey: "QC.CaptureGroupsEnabled")
        }
    }

    @MainActor static func isTypeCaptured(_ type: ClipboardContentType) -> Bool {
        let group = type.captureGroup
        guard enabledCaptureGroups.contains(group) else { return false }
        return capturedTypes.contains(type)
    }

    @MainActor static var excludedBundleIDs: Set<String> {
        get { Set((defaults.array(forKey: "QC.ExcludedApps") as? [String]) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: "QC.ExcludedApps") }
    }

    @MainActor static var soundOnCopy: Bool {
        get { defaults.bool(forKey: "QC.SoundOnCopy") }
        set { defaults.set(newValue, forKey: "QC.SoundOnCopy") }
    }

    @MainActor static var pasteDeliveryMethod: PasteDeliveryMethod {
        get {
            guard let raw = defaults.string(forKey: "QC.PasteDelivery"),
                  let v = PasteDeliveryMethod(rawValue: raw) else { return .standardPaste }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: "QC.PasteDelivery") }
    }

    @MainActor static var linkPreviewsEnabled: Bool {
        get { LinkPreviewService.enabled }
        set { LinkPreviewService.enabled = newValue }
    }

    @MainActor static var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("Launch at login toggle failed: \(error)")
            }
        }
    }

    @MainActor static var quickSearchPlacement: QuickSearchPlacement {
        get {
            guard let raw = defaults.string(forKey: "QC.QSPlacement"),
                  let v = QuickSearchPlacement(rawValue: raw) else { return .screenCenterActive }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: "QC.QSPlacement") }
    }

    @MainActor static var quickSearchDisplayID: CGDirectDisplayID? {
        get {
            let v = defaults.integer(forKey: "QC.QSDisplayID")
            return v == 0 ? nil : CGDirectDisplayID(v)
        }
        set {
            if let v = newValue { defaults.set(Int(v), forKey: "QC.QSDisplayID") }
            else { defaults.removeObject(forKey: "QC.QSDisplayID") }
        }
    }

    static let quickSearchDefaultSize = CGSize(width: 1060, height: 480)
    static let quickSearchDefaultPreviewWidth: CGFloat = 380
    static let quickSearchListLimitDefault = 50
    static let quickSearchListLimitMax = 500

    @MainActor static var quickSearchListLimit: Int {
        get {
            if defaults.object(forKey: "QC.QSListLimit") == nil {
                return quickSearchListLimitDefault
            }
            return clampQuickSearchListLimit(defaults.integer(forKey: "QC.QSListLimit"))
        }
        set { defaults.set(clampQuickSearchListLimit(newValue), forKey: "QC.QSListLimit") }
    }

    @MainActor static func clampQuickSearchListLimit(_ value: Int) -> Int {
        min(quickSearchListLimitMax, max(1, value))
    }

    @MainActor static var quickSearchPreviewEnabled: Bool {
        get { defaults.object(forKey: "QC.QSPreviewEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "QC.QSPreviewEnabled") }
    }

    @MainActor static var quickSearchPreviewWidth: CGFloat {
        get {
            let v = defaults.double(forKey: "QC.QSPreviewWidth")
            return v <= 0 ? quickSearchDefaultPreviewWidth : CGFloat(v)
        }
        set { defaults.set(Double(newValue), forKey: "QC.QSPreviewWidth") }
    }

    @MainActor static var quickSearchLastSize: CGSize? {
        get {
            guard let s = defaults.string(forKey: "QC.QSLastSize") else { return nil }
            let parts = s.split(separator: ",")
            guard parts.count == 2,
                  let w = Double(parts[0]), let h = Double(parts[1]) else { return nil }
            return CGSize(width: w, height: h)
        }
        set {
            if let s = newValue {
                defaults.set("\(s.width),\(s.height)", forKey: "QC.QSLastSize")
            } else {
                defaults.removeObject(forKey: "QC.QSLastSize")
            }
        }
    }

    @MainActor static var autoCategorizationEnabled: Bool {
        get { defaults.object(forKey: "QC.AutoCategorize") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "QC.AutoCategorize") }
    }

    @MainActor static var autoCategorizationML: Bool {
        get { defaults.object(forKey: "QC.AutoCategorizeML") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "QC.AutoCategorizeML") }
    }

    /// When true, suggestions at or above `autoCategorizationAutoApplyThreshold`
    /// are attached to the clip automatically; remaining suggestions stay as banner pending.
    @MainActor static var autoCategorizationAutoApply: Bool {
        get { defaults.object(forKey: "QC.AutoCategorizeAutoApply") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "QC.AutoCategorizeAutoApply") }
    }

    @MainActor static var autoCategorizationAutoApplyThreshold: Double {
        get {
            let v = defaults.object(forKey: "QC.AutoCategorizeAutoApplyThreshold") as? Double
            return v ?? 0.85
        }
        set { defaults.set(newValue, forKey: "QC.AutoCategorizeAutoApplyThreshold") }
    }

    @MainActor static var collapseDuplicates: Bool {
        get { defaults.object(forKey: "QC.CollapseDuplicates") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "QC.CollapseDuplicates") }
    }

    @MainActor static var captureUniversalClipboard: Bool {
        get {
            if defaults.object(forKey: "QC.CaptureUniversalClipboard") == nil { return true }
            return defaults.bool(forKey: "QC.CaptureUniversalClipboard")
        }
        set { defaults.set(newValue, forKey: "QC.CaptureUniversalClipboard") }
    }

    @MainActor static var clipPreviewStyle: ClipPreviewStyle {
        get {
            guard let raw = defaults.string(forKey: "QC.ClipPreviewStyle"),
                  let v = ClipPreviewStyle(rawValue: raw) else { return .rich }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: "QC.ClipPreviewStyle") }
    }

    @MainActor static var popupViewMode: PopupViewMode {
        get {
            guard let raw = defaults.string(forKey: "QC.PopupViewMode"),
                  let v = PopupViewMode(rawValue: raw) else { return .list }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: "QC.PopupViewMode") }
    }

    @MainActor static var libraryGroupBy: LibraryGroupBy {
        get {
            guard let raw = defaults.string(forKey: "QC.LibraryGroupBy"),
                  let v = LibraryGroupBy(rawValue: raw) else { return .contentType }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: "QC.LibraryGroupBy") }
    }

    @MainActor static var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "QC.OnboardingCompleted") }
        set { defaults.set(newValue, forKey: "QC.OnboardingCompleted") }
    }

    @MainActor static var multiPasteDelimiter: MultiPasteDelimiter {
        get {
            guard let raw = defaults.string(forKey: "QC.MultiPasteDelimiter"),
                  let v = MultiPasteDelimiter(rawValue: raw) else { return .newline }
            return v
        }
        set { defaults.set(newValue.rawValue, forKey: "QC.MultiPasteDelimiter") }
    }

    @MainActor static var multiPasteCustomDelimiter: String {
        get { defaults.string(forKey: "QC.MultiPasteCustomDelimiter") ?? "\n\n" }
        set { defaults.set(newValue, forKey: "QC.MultiPasteCustomDelimiter") }
    }

    /// When enabled, picking a clip from Quick Search / pinned slot / Ctrl+Cmd+0–9 also pastes
    /// the clip into the previously-active app (requires Accessibility). When disabled, those
    /// actions only copy the clip to the system clipboard — the user pastes with ⌘V themselves.
    /// Disable this if you don't want to grant Accessibility, or prefer manual paste.
    @MainActor static var autoPasteEnabled: Bool {
        get { defaults.object(forKey: "QC.AutoPasteEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "QC.AutoPasteEnabled") }
    }

    /// One-time-per-session flag so we don't badger the user about Accessibility on every Quick
    /// Search open. Re-shown on next launch if still missing.
    @MainActor static var didPromptAccessibilityThisSession: Bool = false

    /// Restore the user's previous clipboard after pasting a clip. Default OFF — snapshotting and
    /// re-writing the full pasteboard can stall the UI when the prior clipboard holds large
    /// images. Opt in from Settings → General → Paste when you want the Paste/Raycast-style
    /// "leave my working clipboard intact" behavior.
    @MainActor static var restoreClipboardAfterPaste: Bool {
        get { defaults.object(forKey: "QC.RestoreClipboardAfterPaste") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "QC.RestoreClipboardAfterPaste") }
    }

    /// Brief on-screen confirmation HUD after copy / paste actions.
    @MainActor static var showPasteFeedbackHUD: Bool {
        get { defaults.object(forKey: "QC.ShowFeedbackHUD") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "QC.ShowFeedbackHUD") }
    }

    @MainActor static var quickSearchLastOrigin: CGPoint? {
        get {
            guard let s = defaults.string(forKey: "QC.QSLastOrigin") else { return nil }
            let parts = s.split(separator: ",")
            guard parts.count == 2,
                  let x = Double(parts[0]), let y = Double(parts[1]) else { return nil }
            return CGPoint(x: x, y: y)
        }
        set {
            if let p = newValue {
                defaults.set("\(p.x),\(p.y)", forKey: "QC.QSLastOrigin")
            } else {
                defaults.removeObject(forKey: "QC.QSLastOrigin")
            }
        }
    }
}

enum QuickSearchPlacement: String, CaseIterable, Identifiable, Codable {
    case cursor
    case menuIcon
    case windowCenter
    case screenCenterActive
    case screenCenterChosen
    case lastPosition

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .menuIcon: return "Menu icon"
        case .windowCenter: return "Window center"
        case .screenCenterActive: return "Screen center (active)"
        case .screenCenterChosen: return "Screen center (chosen)"
        case .lastPosition: return "Last position"
        }
    }
}
