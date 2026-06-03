import AppKit
import SwiftUI

/// Read-only scrollable rendered RTF / Markdown (via `NSAttributedString`).
struct AttributedTextPreview: NSViewRepresentable {
    let attributedString: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textStorage?.setAttributedString(attributedString)

        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        textView.textStorage?.setAttributedString(attributedString)
    }
}

/// Rendered vs source toggle for markdown / RTF clips.
struct RichContentPreview: View {
    let item: ClipboardItem
    @State private var showSource = false

    private var kind: RichContentRenderer.PreviewKind {
        RichContentRenderer.previewKind(for: item)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if kind != .plain {
                Picker("Preview", selection: $showSource) {
                    Text("Rendered").tag(false)
                    Text("Source").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 220)
            }

            if showSource || kind == .plain {
                sourceView
            } else if let attr = RichContentRenderer.attributedPreview(for: item) {
                AttributedTextPreview(attributedString: attr)
                    .frame(minHeight: 120, maxHeight: .infinity)
            } else {
                sourceView
            }
        }
    }

    @ViewBuilder
    private var sourceView: some View {
        ScrollView {
            Text(sourceText)
                .font(.system(.body, design: sourceMonospaced ? .monospaced : .default))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    private var sourceText: String {
        RichContentRenderer.markdownPlainText(for: item) ?? ""
    }

    private var sourceMonospaced: Bool {
        item.contentType == .code || kind == .markdown
    }
}
