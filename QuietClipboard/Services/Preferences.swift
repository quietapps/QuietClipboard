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

    @MainActor static var excludedBundleIDs: Set<String> {
        get { Set((defaults.array(forKey: "QC.ExcludedApps") as? [String]) ?? []) }
        set { defaults.set(Array(newValue), forKey: "QC.ExcludedApps") }
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
