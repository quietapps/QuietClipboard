import SwiftUI

struct PinnedSlotBadge: View {
    let slotIndex: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "pin.fill")
                .font(compact ? .caption2 : .caption)
            Text("\(slotIndex + 1)")
                .font(compact ? .caption2 : .caption)
                .monospacedDigit()
        }
        .foregroundStyle(.orange)
        .help("Pinned slot \(slotIndex + 1)")
    }
}
