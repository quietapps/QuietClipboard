import SwiftUI

struct PopupItemContextMenu: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let item: ClipboardItem

    var body: some View {
        if PasteSimulator.plainText(from: item) != nil {
            Button {
                coordinator.pastePlainText(item)
            } label: {
                Label("Paste as Plain Text", systemImage: "doc.plaintext")
            }
            Button {
                coordinator.typeItem(item)
            } label: {
                Label("Type into App", systemImage: "keyboard")
            }
        }
        if QuickLookPreview.canPreview(item) {
            Button {
                QuickLookPreview.show(for: item)
            } label: {
                Label("Quick Look", systemImage: "eye")
            }
        }
        if item.contentType == .file,
           let s = item.textContent, let url = URL(string: s), url.isFileURL {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }
        }
        TextTransformMenu(item: item)
    }
}
