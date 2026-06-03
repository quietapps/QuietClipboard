import AppKit
import SwiftUI

enum RichContentPreviewStyle {
    case standard
    case panel
}

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
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 2, height: 4)
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
        textView.textColor = .labelColor
        textView.textStorage?.setAttributedString(attributedString)
    }
}

struct PreviewContentCard<Content: View>: View {
    var style: RichContentPreviewStyle = .standard
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(style == .panel ? 12 : 8)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }
}

struct MarkdownTablePreview: View {
    let table: ParsedMarkdownTable

    private var columnCount: Int {
        max(table.headers.count, table.rows.map(\.count).max() ?? 0)
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { column in
                        Text(column < table.headers.count ? table.headers[column] : "")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(minWidth: 72, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                }
                .background(Color.primary.opacity(0.06))

                ForEach(table.rows.indices, id: \.self) { rowIndex in
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { column in
                            Text(cellText(in: table.rows[rowIndex], column: column))
                                .font(cellFont(for: cellText(in: table.rows[rowIndex], column: column)))
                                .monospacedDigit()
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .frame(minWidth: 72, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                        }
                    }
                    .background(rowIndex.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.03))
                }
            }
        }
    }

    private func cellText(in row: [String], column: Int) -> String {
        column < row.count ? row[column] : ""
    }

    private func cellFont(for text: String) -> Font {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .callout }
        let numericCharacters = CharacterSet(charactersIn: "0123456789.,%-+$ ")
        let isNumeric = trimmed.unicodeScalars.allSatisfy { numericCharacters.contains($0) }
        return isNumeric ? .system(.callout, design: .monospaced) : .callout
    }
}

/// Rendered vs source toggle for markdown / RTF clips.
struct RichContentPreview: View {
    let item: ClipboardItem
    var style: RichContentPreviewStyle = .standard
    @State private var showSource = false

    private var kind: RichContentRenderer.PreviewKind {
        RichContentRenderer.previewKind(for: item)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style == .panel ? 10 : 8) {
            if kind != .plain {
                previewModeToggle
            }

            PreviewContentCard(style: style) {
                previewContent
            }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if showSource || kind == .plain {
            sourceView
        } else if let table = RichContentRenderer.parsedMarkdownTable(for: item) {
            MarkdownTablePreview(table: table)
        } else if let attr = RichContentRenderer.appearanceAdaptedPreview(for: item) {
            AttributedTextPreview(attributedString: attr)
                .frame(minHeight: style == .panel ? 100 : 120, maxHeight: .infinity)
        } else {
            sourceView
        }
    }

    private var previewModeToggle: some View {
        HStack(spacing: 6) {
            previewModeButton(
                title: "Rendered",
                icon: "doc.richtext",
                isActive: !showSource
            ) {
                showSource = false
            }
            previewModeButton(
                title: "Source",
                icon: "chevron.left.forwardslash.chevron.right",
                isActive: showSource
            ) {
                showSource = true
            }
            Spacer(minLength: 0)
        }
    }

    private func previewModeButton(
        title: String,
        icon: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(isActive ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    isActive ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05),
                    in: Capsule()
                )
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var sourceView: some View {
        ScrollView {
            Text(sourceText)
                .font(.system(style == .panel ? .callout : .body, design: sourceMonospaced ? .monospaced : .default))
                .foregroundStyle(.primary)
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
