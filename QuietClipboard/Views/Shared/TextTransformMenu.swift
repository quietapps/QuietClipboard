import SwiftUI
import SwiftData
import AppKit

struct TextTransformMenu: View {
    let item: ClipboardItem

    var body: some View {
        if TextClipTransform.supports(item) {
            Menu {
                ForEach(TextClipTransform.allCases) { transform in
                    Button {
                        // Non-destructive: put the transformed result on the clipboard (the monitor
                        // captures it as a new clip). The original item is left untouched.
                        guard let result = TextClipTransforms.transformedText(transform, for: item) else { return }
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(result, forType: .string)
                    } label: {
                        Text(transform.title)
                    }
                }
            } label: {
                Label("Transform & Copy", systemImage: "textformat")
            }
        }
    }
}
