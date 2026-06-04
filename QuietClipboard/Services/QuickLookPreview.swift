import AppKit
import Quartz

/// Quick Look preview for file and image clips. File clips preview the original URL; image clips
/// are written to a temp PNG and previewed from there.
@MainActor
final class QuickLookPreview: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookPreview()

    private var urls: [URL] = []

    static func canPreview(_ item: ClipboardItem) -> Bool {
        switch item.contentType {
        case .file, .image, .screenshot: return true
        default: return false
        }
    }

    static func show(for item: ClipboardItem) {
        guard let url = shared.prepareURL(for: item) else { return }
        shared.urls = [url]
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = shared
        panel.delegate = shared
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    private func prepareURL(for item: ClipboardItem) -> URL? {
        switch item.contentType {
        case .file:
            guard let s = item.textContent, let u = URL(string: s), u.isFileURL,
                  FileManager.default.fileExists(atPath: u.path) else { return nil }
            return u
        case .image, .screenshot:
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("qc-ql-\(item.id.uuidString).png")
            let data = ThumbnailGenerator.pngData(forImageData: item.content) ?? item.content
            do { try data.write(to: url); return url } catch { return nil }
        default:
            return nil
        }
    }

    // MARK: QLPreviewPanelDataSource

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel) -> Int {
        MainActor.assumeIsolated { urls.count }   // Quick Look invokes the data source on the main thread
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel, previewItemAt index: Int) -> QLPreviewItem {
        MainActor.assumeIsolated { urls[index] as NSURL }
    }
}
