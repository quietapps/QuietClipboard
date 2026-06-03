import SwiftUI
import SwiftData

/// Slot shelf for permanent pins. Shown compact at popup bottom when the Pinned filter is active.
struct PinnedSlotsPanel: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @ObservedObject private var pinned = PinnedClipStore.shared

    let items: [ClipboardItem]
    var selectedItemID: UUID?
    let onActivate: (ClipboardItem) -> Void
    var onAssignSelectionToSlot: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Slots")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("⌃⌥⌘1–0")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(pinned.filledSlotCount())/\(PinnedClipStore.slotCount)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)

            HorizontalScrollBar(barHeight: 44, showsHorizontalScroller: true) {
                HStack(spacing: 6) {
                    ForEach(0..<PinnedClipStore.slotCount, id: \.self) { slot in
                        PinnedSlotCell(
                            slot: slot,
                            item: item(for: slot),
                            isSelectionTarget: selectedItemID != nil && item(for: slot) == nil,
                            onActivate: onActivate,
                            onAssign: {
                                if let onAssignSelectionToSlot {
                                    onAssignSelectionToSlot(slot)
                                } else if let id = selectedItemID {
                                    pinned.pin(itemID: id, to: slot)
                                }
                            },
                            onUnpin: { pinned.unpin(slot: slot) }
                        )
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pinned slots")
    }

    private func item(for slot: Int) -> ClipboardItem? {
        guard let id = pinned.itemID(for: slot) else { return nil }
        return items.first(where: { $0.id == id })
    }
}

private struct PinnedSlotCell: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    let slot: Int
    let item: ClipboardItem?
    var isSelectionTarget: Bool = false
    let onActivate: (ClipboardItem) -> Void
    let onAssign: () -> Void
    let onUnpin: () -> Void

    private let width: CGFloat = 72
    private let height: CGFloat = 40

    var body: some View {
        Button(action: tap) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    slotLabel
                    Spacer(minLength: 0)
                    if item?.isSensitive == true,
                       let item,
                       !coordinator.isSensitiveRevealed(item.id) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(previewTitle)
                    .font(.system(size: 9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(item == nil ? .tertiary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .help(helpText)
        .contextMenu { contextMenu }
    }

    private var previewTitle: String {
        if let item {
            if item.isSensitive, !coordinator.isSensitiveRevealed(item.id) {
                return "Sensitive"
            }
            let t = item.title ?? item.textContent ?? item.contentType.displayName
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return isSelectionTarget ? "Assign" : "Empty"
    }

    private var slotLabel: some View {
        Text("\(slot + 1)")
            .font(.system(size: 9, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(item != nil ? Color.orange : Color.secondary.opacity(0.55),
                        in: Capsule())
    }

    private var borderColor: Color {
        if item != nil { return Color.orange.opacity(0.45) }
        if isSelectionTarget { return Color.accentColor.opacity(0.55) }
        return Color.secondary.opacity(0.22)
    }

    private var helpText: String {
        if let item {
            return "Slot \(slot + 1): paste \(item.title ?? "clip")"
        }
        if isSelectionTarget {
            return "Slot \(slot + 1): assign selected clip"
        }
        return "Slot \(slot + 1): empty"
    }

    private func tap() {
        if let item {
            guard coordinator.shouldProceedWithSensitiveAction(for: item) else { return }
            onActivate(item)
        } else if isSelectionTarget {
            onAssign()
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        if let item {
            Button {
                guard coordinator.shouldProceedWithSensitiveAction(for: item) else { return }
                onActivate(item)
            } label: {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            Divider()
            Button(role: .destructive, action: onUnpin) {
                Label("Unpin", systemImage: "pin.slash")
            }
        } else if isSelectionTarget {
            Button(action: onAssign) {
                Label("Assign selected", systemImage: "pin")
            }
        }
    }
}
