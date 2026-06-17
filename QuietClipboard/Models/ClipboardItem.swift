import Foundation
import SwiftData

@Model
final class ClipboardItem {
    // Dedupe lookups hit contentHash on every capture; list views sort on the timestamps and
    // filter on the type column. Without these, each is a full table scan.
    #Index<ClipboardItem>([\.contentHash], [\.createdAt], [\.lastCopiedAt], [\.contentTypeRaw])

    @Attribute(.unique) var id: UUID
    // The raw clipboard payload is the heaviest field (images/files/RTF) and is only needed at
    // paste/drag time — never for rendering cards, which use `thumbnailData`/`textContent`.
    // External storage keeps it out of the SQLite row so `@Query` fetches don't fault tens of MB
    // of blobs into memory just to draw the Library grid.
    @Attribute(.externalStorage) var content: Data
    var contentHash: String = ""
    var contentTypeRaw: String
    var textContent: String?
    var ocrText: String?
    var title: String?
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var thumbnailData: Data?
    var linkPreviewTitle: String?
    var linkPreviewDescription: String?
    var linkPreviewImageData: Data?
    var colorHex: String?
    var fileSize: Int64?
    var fileMIMEType: String?
    var isFavorite: Bool
    var isSensitive: Bool
    var createdAt: Date
    var modifiedAt: Date

    var copyCount: Int = 1
    var firstCopiedAt: Date?
    var lastCopiedAt: Date?
    var normalizedFingerprint: String = ""
    var duplicateGroupID: UUID?
    var pendingSuggestionsJSON: String?
    /// JSON-encoded `StructuredDataMatch` when clip is a single structured value.
    var structuredDataJSON: String?

    @Relationship(inverse: \Category.items) var categories: [Category]
    @Relationship(deleteRule: .cascade, inverse: \ClipboardCopyEvent.item) var copyEvents: [ClipboardCopyEvent]

    var contentType: ClipboardContentType {
        get { ClipboardContentType(rawValue: contentTypeRaw) ?? .other }
        set { contentTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        content: Data,
        contentHash: String = "",
        contentType: ClipboardContentType,
        textContent: String? = nil,
        title: String? = nil,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        thumbnailData: Data? = nil,
        colorHex: String? = nil,
        fileSize: Int64? = nil,
        fileMIMEType: String? = nil,
        isFavorite: Bool = false,
        isSensitive: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.content = content
        self.contentHash = contentHash
        self.contentTypeRaw = contentType.rawValue
        self.textContent = textContent
        self.title = title
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.thumbnailData = thumbnailData
        self.colorHex = colorHex
        self.fileSize = fileSize
        self.fileMIMEType = fileMIMEType
        self.isFavorite = isFavorite
        self.isSensitive = isSensitive
        self.createdAt = createdAt
        self.modifiedAt = createdAt
        self.firstCopiedAt = createdAt
        self.lastCopiedAt = createdAt
        self.copyCount = 1
        self.categories = []
        self.copyEvents = []
    }
}
