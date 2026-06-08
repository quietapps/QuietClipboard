import SwiftUI

/// List row for Quick Search and menu bar popover: activate on main area, delete on the right.
struct PopupClipRow: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject private var pinned = PinnedClipStore.shared
    let item: ClipboardItem
    let isSelected: Bool
    var isMultiSelected: Bool = false
    /// True when any item in the list is currently multi-selected. Plain clicks
    /// then route to `onModifierActivate` (toggle membership) instead of `onActivate`.
    var multiSelectionActive: Bool = false
    let onActivate: () -> Void
    var onModifierActivate: ((NSEvent.ModifierFlags) -> Void)? = nil
    let onTogglePin: () -> Void
    let onToggleFavorite: () -> Void
    let onDelete: () -> Void

    @AppStorage("QC.ClipPreviewStyle") private var styleRaw: String = ClipPreviewStyle.rich.rawValue

    private var clipPreviewStyle: ClipPreviewStyle {
        ClipPreviewStyle(rawValue: styleRaw) ?? .rich
    }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                let flags = NSApp.currentEvent?.modifierFlags ?? []
                let modifierHeld = !flags.intersection([.command, .shift]).isEmpty
                if let mod = onModifierActivate, (modifierHeld || multiSelectionActive) {
                    mod(flags)
                    return
                }
                if coordinator.shouldProceedWithSensitiveAction(for: item) {
                    onActivate()
                }
            }) {
                HStack(spacing: 10) {
                    if isMultiSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.system(size: 14))
                    }
                    ClipRowLeadingAccessory(
                        item: item,
                        richSize: CGSize(
                            width: clipPreviewStyle == .compact ? 22 : 50,
                            height: clipPreviewStyle == .compact ? 22 : 50
                        )
                    )
                    if clipPreviewStyle == .compact {
                        SensitiveClipLabel(
                            item: item,
                            font: .callout,
                            lineLimit: 1,
                            monospaced: item.contentType == .code,
                            inlineMultiline: true
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            SensitiveClipLabel(
                                item: item,
                                font: .body,
                                lineLimit: 1,
                                monospaced: item.contentType == .code,
                                inlineMultiline: true
                            )
                            HStack(spacing: 6) {
                                StructuredDataBadgeRow(item: item, compact: true)
                                Image(systemName: item.contentType.systemImage).font(.caption2)
                                Text(item.contentType.displayName).font(.caption2)
                                Text("·").font(.caption2)
                                ClipSourceIcon(item: item, size: 10)
                                Text(item.sourceAppName ?? "Unknown").font(.caption2)
                                if item.distinctSourceAppNames.count > 1 {
                                    Text("+\(item.distinctSourceAppNames.count - 1)")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.15), in: Capsule())
                                        .help("Also copied from " + item.distinctSourceAppNames.dropFirst().joined(separator: ", "))
                                }
                                Text("·").font(.caption2)
                                Text(DateFormatting.relativeString(from: item.effectiveLastCopiedAt)).font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerCursor()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(activateLabel)
            .accessibilityValue(activateValue)
            .accessibilityHint("Pastes into the previous app")

            Button(action: onTogglePin) {
                Image(systemName: pinned.isPinned(item.id) ? "pin.fill" : "pin")
                    .font(.body)
                    .foregroundStyle(pinned.isPinned(item.id) ? .orange : .secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .pointerCursor()
            .help(pinHelp)
            .accessibilityLabel(pinned.isPinned(item.id) ? "Unpin" : "Pin to slot")

            Button(action: onToggleFavorite) {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .font(.body)
                    .foregroundStyle(item.isFavorite ? .yellow : .secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .pointerCursor()
            .help(item.isFavorite ? "Remove from favorites" : "Add to favorites")
            .accessibilityLabel(item.isFavorite ? "Remove from favorites" : "Add to favorites")

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .pointerCursor()
            .help("Delete from history")
            .accessibilityLabel("Delete from history")
        }
        .padding(.leading, 8)
        .padding(.trailing, 4)
        .padding(.vertical, clipPreviewStyle == .compact ? 1 : 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isMultiSelected
                        ? Color.accentColor.opacity(0.35)
                        : (isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
                )
        )
        .contextMenu {
            PopupItemContextMenu(item: item)
        }
    }

    private var activateLabel: String {
        var parts = ["\(item.contentType.displayName) clip"]
        if let app = item.sourceAppName { parts.append("from \(app)") }
        if pinned.isPinned(item.id) { parts.append("pinned") }
        if item.isFavorite { parts.append("favorite") }
        if isMultiSelected { parts.append("selected") }
        return parts.joined(separator: ", ")
    }

    /// Never read raw content aloud for sensitive clips — mirror the on-screen redaction.
    private var activateValue: String {
        if item.isSensitive { return "Hidden sensitive content" }
        return item.title ?? item.textContent ?? ""
    }

    private var pinHelp: String {
        if let slot = pinned.slotIndex(for: item.id) {
            return "Unpin from slot \(slot + 1) (⌥P)"
        }
        return "Pin to slot (⌥P)"
    }
}
