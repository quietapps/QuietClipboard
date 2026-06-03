import SwiftUI
import SwiftData

struct TextTransformMenu: View {
    @Environment(\.modelContext) private var context
    let item: ClipboardItem

    var body: some View {
        if TextClipTransform.supports(item) {
            Menu {
                ForEach(TextClipTransform.allCases) { transform in
                    Button {
                        TextClipTransforms.apply(transform, to: item, context: context)
                    } label: {
                        Text(transform.title)
                    }
                }
            } label: {
                Label("Transform", systemImage: "textformat")
            }
        }
    }
}
