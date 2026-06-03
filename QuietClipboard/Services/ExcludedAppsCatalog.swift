import AppKit

/// Recommended bundle IDs for password managers and banking apps (auto-seeded once).
enum ExcludedAppsCatalog {
    struct Entry: Identifiable {
        let bundleID: String
        let name: String
        var id: String { bundleID }
    }

    static let recommended: [Entry] = [
        Entry(bundleID: "com.1password.1password", name: "1Password"),
        Entry(bundleID: "com.agilebits.onepassword7", name: "1Password 7"),
        Entry(bundleID: "com.bitwarden.desktop", name: "Bitwarden"),
        Entry(bundleID: "com.lastpass.LastPass", name: "LastPass"),
        Entry(bundleID: "com.dashlane.Dashlane", name: "Dashlane"),
        Entry(bundleID: "org.keepassxc.keepassxc", name: "KeePassXC"),
        Entry(bundleID: "in.enpass.desktop", name: "Enpass"),
        Entry(bundleID: "ch.protonmail.pass", name: "Proton Pass"),
        Entry(bundleID: "com.apple.keychainaccess", name: "Keychain Access"),
        Entry(bundleID: "com.chase.signon", name: "Chase"),
        Entry(bundleID: "com.bankofamerica.BofA", name: "Bank of America"),
        Entry(bundleID: "com.wellsfargo.WellsFargo", name: "Wells Fargo"),
        Entry(bundleID: "com.citi.citimobile", name: "Citi"),
        Entry(bundleID: "com.capitalone.capitalone", name: "Capital One"),
        Entry(bundleID: "com.usaa.mobilebanking", name: "USAA"),
        Entry(bundleID: "com.microsoft.rdc.macos", name: "Windows App (RDP)"),
        Entry(bundleID: "com.microsoft.rdc", name: "Microsoft Remote Desktop"),
        Entry(bundleID: "com.apple.ScreenSharing", name: "Screen Sharing"),
    ]

    static var recommendedBundleIDs: Set<String> {
        Set(recommended.map(\.bundleID))
    }

    static func displayName(for bundleID: String) -> String {
        if let entry = recommended.first(where: { $0.bundleID == bundleID }) {
            return entry.name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return bundleID
    }

    static func bundleID(from appURL: URL) -> String? {
        guard let bundle = Bundle(url: appURL) else { return nil }
        return bundle.bundleIdentifier
    }

    @MainActor
    static func seedDefaultsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "QC.ExcludedAppsSeeded") else { return }
        var ids = Preferences.excludedBundleIDs
        ids.formUnion(recommendedBundleIDs)
        Preferences.excludedBundleIDs = ids
        UserDefaults.standard.set(true, forKey: "QC.ExcludedAppsSeeded")
    }
}
