import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DraggableClip: Codable, Transferable {
    var text: String?
    var imageData: Data?
    var fileURLString: String?

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { clip in
            clip.imageData ?? Data()
        }
        DataRepresentation(exportedContentType: .fileURL) { clip in
            Data((clip.fileURLString ?? "").utf8)
        }
        ProxyRepresentation(exporting: { clip in clip.text ?? "" })
    }

    init(item: ClipboardItem) {
        switch item.contentType {
        case .image, .screenshot:
            self.imageData = item.content
        case .file:
            self.fileURLString = item.textContent
        default:
            self.text = item.textContent
        }
    }
}
