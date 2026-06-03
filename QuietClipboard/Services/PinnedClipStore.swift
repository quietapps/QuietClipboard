import Foundation
import SwiftData
import Combine

/// User-assigned permanent slots (0–9), separate from recent-order paste (Ctrl+Cmd+0–9).
@MainActor
final class PinnedClipStore: ObservableObject {
    static let shared = PinnedClipStore()
    static let slotCount = 10

    @Published private(set) var slotItemIDs: [Int: UUID]

    private let defaultsKey = "QuietClipboard.PinnedSlots"

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            var map: [Int: UUID] = [:]
            for (k, v) in decoded {
                guard let slot = Int(k), let id = UUID(uuidString: v) else { continue }
                guard (0..<Self.slotCount).contains(slot) else { continue }
                map[slot] = id
            }
            slotItemIDs = map
        } else {
            slotItemIDs = [:]
        }
    }

    func slotIndex(for itemID: UUID) -> Int? {
        slotItemIDs.first(where: { $0.value == itemID })?.key
    }

    func itemID(for slot: Int) -> UUID? {
        guard (0..<Self.slotCount).contains(slot) else { return nil }
        return slotItemIDs[slot]
    }

    func isPinned(_ itemID: UUID) -> Bool {
        slotIndex(for: itemID) != nil
    }

    func filledSlotCount() -> Int {
        slotItemIDs.count
    }

    func allPinnedItemIDs() -> Set<UUID> {
        Set(slotItemIDs.values)
    }

    /// Slots 0…9 in order; only filled slots.
    func orderedItemIDs() -> [UUID] {
        (0..<Self.slotCount).compactMap { slotItemIDs[$0] }
    }

    /// Pin to `slot`, or first free slot when `slot` is nil. Returns assigned slot.
    @discardableResult
    func pin(itemID: UUID, to slot: Int? = nil) -> Int? {
        var map = slotItemIDs
        if let existing = map.first(where: { $0.value == itemID })?.key {
            map.removeValue(forKey: existing)
        }
        let target: Int?
        if let slot, (0..<Self.slotCount).contains(slot) {
            target = slot
        } else {
            target = (0..<Self.slotCount).first(where: { map[$0] == nil })
        }
        guard let target else { return nil }
        map[target] = itemID
        apply(map)
        return target
    }

    func unpin(itemID: UUID) {
        guard let slot = slotIndex(for: itemID) else { return }
        unpin(slot: slot)
    }

    func unpin(slot: Int) {
        guard (0..<Self.slotCount).contains(slot) else { return }
        var map = slotItemIDs
        map.removeValue(forKey: slot)
        apply(map)
    }

    /// Toggle: unpin if pinned, else pin to first free slot.
    @discardableResult
    func togglePin(itemID: UUID) -> Int? {
        if let slot = slotIndex(for: itemID) {
            unpin(slot: slot)
            return nil
        }
        return pin(itemID: itemID)
    }

    func clearAll() {
        apply([:])
    }

    func pruneMissingItems(context: ModelContext) {
        guard let items = try? context.fetch(FetchDescriptor<ClipboardItem>()) else { return }
        let valid = Set(items.map(\.id))
        var map = slotItemIDs
        for (slot, id) in map where !valid.contains(id) {
            map.removeValue(forKey: slot)
        }
        guard map != slotItemIDs else { return }
        apply(map)
    }

    func resolveItem(slot: Int, context: ModelContext) -> ClipboardItem? {
        guard let id = itemID(for: slot) else { return nil }
        let captured = id
        let desc = FetchDescriptor<ClipboardItem>(predicate: #Predicate { $0.id == captured })
        return try? context.fetch(desc).first
    }

    private func apply(_ map: [Int: UUID]) {
        slotItemIDs = map
        persist()
    }

    private func persist() {
        let raw = slotItemIDs.reduce(into: [String: String]()) { $0[String($1.key)] = $1.value.uuidString }
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
