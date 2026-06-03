import Foundation
import SwiftData

@Model
final class ClipboardCopyEvent {
    @Attribute(.unique) var id: UUID
    var copiedAt: Date
    var sourceAppBundleID: String?
    var sourceAppName: String?

    var item: ClipboardItem?

    init(
        id: UUID = UUID(),
        copiedAt: Date = .now,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil
    ) {
        self.id = id
        self.copiedAt = copiedAt
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
    }
}
