import SwiftUI
import AppKit
import UniformTypeIdentifiers

private enum ExcludedAppLayout {
    /// Chips and toolbar buttons share one row height for visual balance.
    static let rowHeight: CGFloat = 36
    static let iconSize: CGFloat = 22
    static let cornerRadius: CGFloat = 8
    static let gridSpacing: CGFloat = 8
    static let columns = [GridItem(.adaptive(minimum: 128, maximum: 200), spacing: gridSpacing)]
}

struct ExcludedAppsSettingsView: View {
    @State private var excludedIDs: [String] = []
    @State private var showRecommended = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if excludedIDs.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: ExcludedAppLayout.columns, alignment: .leading, spacing: ExcludedAppLayout.gridSpacing) {
                    ForEach(excludedIDs, id: \.self) { bundleID in
                        ExcludedAppChip(
                            bundleID: bundleID,
                            displayName: ExcludedAppsCatalog.displayName(for: bundleID),
                            onRemove: { remove(bundleID) }
                        )
                    }
                }
            }

            HStack(spacing: ExcludedAppLayout.gridSpacing) {
                SettingsActionButton(
                    title: "Add app",
                    systemImage: "plus",
                    variant: .secondary,
                    size: .compact,
                    action: pickApplication
                )
                .frame(maxWidth: .infinity)

                SettingsActionButton(
                    title: "Recommended",
                    systemImage: "sparkles",
                    variant: .secondary,
                    size: .compact
                ) {
                    showRecommended = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { reload() }
        .sheet(isPresented: $showRecommended) {
            RecommendedExcludedAppsSheet(excludedIDs: $excludedIDs, onSave: persist)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "app.badge.checkmark")
                .font(.body)
                .foregroundStyle(SettingsChrome.secondaryText)
            SettingsCaption("No excluded apps. Copies from the frontmost app are always captured.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
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

// MARK: - App chip

private struct ExcludedAppChip: View {
    let bundleID: String
    let displayName: String
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            AppBundleIcon(bundleID: bundleID, size: ExcludedAppLayout.iconSize)

            Text(displayName)
                .font(.caption.weight(.medium))
                .foregroundStyle(SettingsChrome.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(SettingsChrome.secondaryText, SettingsChrome.controlFill)
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .help("Remove \(displayName)")
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: ExcludedAppLayout.rowHeight, alignment: .leading)
        .background(SettingsChrome.controlFill, in: chipShape)
        .overlay(chipShape.stroke(SettingsChrome.cardStroke, lineWidth: 1))
        .help(bundleID)
    }

    private var chipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ExcludedAppLayout.cornerRadius, style: .continuous)
    }
}

// MARK: - App icon

struct AppBundleIcon: View {
    let bundleID: String
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app.dashed")
                    .font(.system(size: max(8, size * 0.5)))
                    .foregroundStyle(SettingsChrome.secondaryText)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Recommended sheet

private struct RecommendedExcludedAppsSheet: View {
    @Binding var excludedIDs: [String]
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recommended exclusions")
                    .font(.headline)
                    .foregroundStyle(SettingsChrome.primaryText)
                Text("Password managers, banking apps, and remote desktop tools.")
                    .font(.caption)
                    .foregroundStyle(SettingsChrome.secondaryText)
            }

            ScrollView {
                LazyVGrid(columns: ExcludedAppLayout.columns, alignment: .leading, spacing: ExcludedAppLayout.gridSpacing) {
                    ForEach(ExcludedAppsCatalog.recommended) { entry in
                        RecommendedAppPickChip(
                            entry: entry,
                            isSelected: selected.contains(entry.bundleID),
                            isAlreadyExcluded: excludedIDs.contains(entry.bundleID)
                        ) {
                            toggle(entry.bundleID)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                SettingsActionButton(
                    title: "Add selected",
                    systemImage: "plus",
                    variant: .primary
                ) {
                    let merged = Set(excludedIDs).union(selected)
                    excludedIDs = merged.sorted {
                        ExcludedAppsCatalog.displayName(for: $0).localizedCaseInsensitiveCompare(
                            ExcludedAppsCatalog.displayName(for: $1)
                        ) == .orderedAscending
                    }
                    onSave()
                    dismiss()
                }
                .frame(minWidth: 140, maxWidth: 180)
                .disabled(selected.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 440, minHeight: 380, maxHeight: 520)
        .background(SettingsChrome.shellBackground)
        .onAppear {
            selected = Set(
                ExcludedAppsCatalog.recommended
                    .map(\.bundleID)
                    .filter { !excludedIDs.contains($0) }
            )
        }
    }

    private func toggle(_ bundleID: String) {
        guard !excludedIDs.contains(bundleID) else { return }
        if selected.contains(bundleID) {
            selected.remove(bundleID)
        } else {
            selected.insert(bundleID)
        }
    }
}

private struct RecommendedAppPickChip: View {
    let entry: ExcludedAppsCatalog.Entry
    let isSelected: Bool
    let isAlreadyExcluded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                AppBundleIcon(bundleID: entry.bundleID, size: ExcludedAppLayout.iconSize)
                    .opacity(isAlreadyExcluded ? 0.45 : 1)

                Text(entry.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(
                        isAlreadyExcluded ? SettingsChrome.tertiaryText : SettingsChrome.primaryText
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                statusIcon
            }
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: ExcludedAppLayout.rowHeight, alignment: .leading)
            .background(chipBackground, in: chipShape)
            .overlay(chipShape.stroke(chipBorder, lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .disabled(isAlreadyExcluded)
        .help(isAlreadyExcluded ? "Already excluded" : entry.bundleID)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isAlreadyExcluded {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(SettingsChrome.tertiaryText)
        } else if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white)
        }
    }

    private var chipShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ExcludedAppLayout.cornerRadius, style: .continuous)
    }

    private var chipBackground: Color {
        if isSelected { return Color.white.opacity(0.14) }
        return SettingsChrome.controlFill
    }

    private var chipBorder: Color {
        if isSelected { return Color.white.opacity(0.35) }
        return SettingsChrome.cardStroke
    }
}
