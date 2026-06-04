import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case capture
    case privacy
    case accessibility
    case shortcuts
    case ready

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: return "Welcome to Quiet Clipboard"
        case .capture: return "Everything you copy, saved locally"
        case .privacy: return "Apps we skip by default"
        case .accessibility: return "Paste back where you were"
        case .shortcuts: return "Keyboard shortcuts"
        case .ready: return "You're all set"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "A private clipboard history for your Mac. No cloud, no account — your clips stay on this machine."
        case .capture:
            return "Text, links, images, code, and files are captured automatically while the app runs in your menu bar."
        case .privacy:
            return "Password managers and Keychain Access are excluded by default so secrets are not stored. Add more anytime in Settings → Capture."
        case .accessibility:
            return "Quick Search and shortcut paste need Accessibility so clips return to the app you were using before opening Quiet Clipboard."
        case .shortcuts:
            return "Use these anytime. Remap them in Settings → Keys."
        case .ready:
            return "Open Quick Search, browse the Library, or peek recent clips from the menu bar icon."
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: return "doc.on.clipboard.fill"
        case .capture: return "tray.full.fill"
        case .privacy: return "lock.shield.fill"
        case .accessibility: return "hand.point.up.left.fill"
        case .shortcuts: return "command"
        case .ready: return "sparkles"
        }
    }

    var iconTint: Color {
        switch self {
        case .welcome: return SettingsChrome.accent
        case .capture: return Color(red: 0.35, green: 0.72, blue: 1.0)
        case .privacy: return Color(red: 0.95, green: 0.55, blue: 0.35)
        case .accessibility: return Color(red: 0.45, green: 0.82, blue: 0.55)
        case .shortcuts: return Color(red: 0.72, green: 0.55, blue: 1.0)
        case .ready: return Color(red: 1.0, green: 0.82, blue: 0.35)
        }
    }
}

struct OnboardingShortcutRow: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let combo: String
    let systemImage: String
}
