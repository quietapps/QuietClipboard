import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExcludedAppsSettingsView: View {
    @State private var excludedIDs: [String] = []
    @State private var showRecommended = false

    var body: some View {
        Group {
            if excludedIDs.isEmpty {
                Text("No excluded apps. Copies from the frontmost app are always captured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(excludedIDs, id: \.self) { bundleID in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ExcludedAppsCatalog.displayName(for: bundleID))
                            Text(bundleID)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            remove(bundleID)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                Button("Add app…", action: pickApplication)
                Button("Add recommended…") {
                    showRecommended = true
                }
            }
        }
        .onAppear { reload() }
        .sheet(isPresented: $showRecommended) {
            RecommendedExcludedAppsSheet(excludedIDs: $excludedIDs, onSave: persist)
        }
    }

    private func reload() {
        excludedIDs = Preferences.excludedBundleIDs.sorted {
            ExcludedAppsCatalog.displayName(for: $0).localizedCaseInsensitiveCompare(
                ExcludedAppsCatalog.displayName(for: $1)
            ) == .orderedAscending
        }
    }

    private func persist() {
        Preferences.excludedBundleIDs = Set(excludedIDs)
    }

    private func remove(_ bundleID: String) {
        excludedIDs.removeAll { $0 == bundleID }
        persist()
    }

    private func pickApplication() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "Choose an app to exclude from clipboard capture"
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = ExcludedAppsCatalog.bundleID(from: url) else { return }
        if !excludedIDs.contains(bundleID) {
            excludedIDs.append(bundleID)
            excludedIDs.sort {
                ExcludedAppsCatalog.displayName(for: $0).localizedCaseInsensitiveCompare(
                    ExcludedAppsCatalog.displayName(for: $1)
                ) == .orderedAscending
            }
            persist()
        }
    }
}

private struct RecommendedExcludedAppsSheet: View {
    @Binding var excludedIDs: [String]
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended exclusions")
                .font(.headline)
            Text("Password managers, banking apps, and remote desktop tools.")
                .font(.caption)
                .foregroundStyle(.secondary)
            List(ExcludedAppsCatalog.recommended) { entry in
                Toggle(isOn: Binding(
                    get: { selected.contains(entry.bundleID) },
                    set: { on in
                        if on { selected.insert(entry.bundleID) }
                        else { selected.remove(entry.bundleID) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                        Text(entry.bundleID)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add selected") {
                    let merged = Set(excludedIDs).union(selected)
                    excludedIDs = merged.sorted {
                        ExcludedAppsCatalog.displayName(for: $0).localizedCaseInsensitiveCompare(
                            ExcludedAppsCatalog.displayName(for: $1)
                        ) == .orderedAscending
                    }
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 440)
        .onAppear {
            selected = Set(
                ExcludedAppsCatalog.recommended
                    .map(\.bundleID)
                    .filter { !excludedIDs.contains($0) }
            )
        }
    }
}
