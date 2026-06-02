import Foundation
import SwiftData

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var color: String
    var sortOrder: Int
    var createdAt: Date
    var items: [ClipboardItem]

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder",
        color: String = "#6E7681",
        sortOrder: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.items = []
    }
}
