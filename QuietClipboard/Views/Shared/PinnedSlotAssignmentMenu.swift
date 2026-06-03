import SwiftUI

struct PinnedSlotAssignmentMenu: View {
    let item: ClipboardItem

    @ObservedObject private var pinned = PinnedClipStore.shared

    var body: some View {
        Menu {
            ForEach(0..<PinnedClipStore.slotCount, id: \.self) { slot in
                Button {
                    pinned.pin(itemID: item.id, to: slot)
                } label: {
                    slotLabel(slot)
                }
            }
            if pinned.isPinned(item.id) {
                Divider()
                Button("Unpin", role: .destructive) {
                    pinned.unpin(itemID: item.id)
                }
            }
        } label: {
            Label(pinMenuTitle, systemImage: "pin")
        }
    }

    private var pinMenuTitle: String {
        if let slot = pinned.slotIndex(for: item.id) {
            return "Pinned (Slot \(slot + 1))"
        }
        return "Pin to Slot"
    }

    @ViewBuilder
    private func slotLabel(_ slot: Int) -> some View {
        let assigned = pinned.itemID(for: slot)
        let isCurrent = assigned == item.id
        if isCurrent {
            Label("Slot \(slot + 1) ✓", systemImage: "pin.fill")
        } else if assigned != nil {
            Label("Slot \(slot + 1) (replace)", systemImage: "pin")
        } else {
            Label("Slot \(slot + 1)", systemImage: "pin")
        }
    }
}
