import SwiftUI

struct LibraryPasteQueueBar: View {
    @ObservedObject var state: LibraryState
    let orderedItems: [ClipboardItem]
    var onPaste: () -> Void
    var onClear: () -> Void

    @State private var delimiter: MultiPasteDelimiter = Preferences.multiPasteDelimiter
    @State private var customDelimiter: String = Preferences.multiPasteCustomDelimiter

    private var canPaste: Bool { orderedItems.count >= 2 }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(red: 0.35, green: 0.58, blue: 1.0))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(state.pasteQueueCount) in paste queue")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(pasteOrderHint)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            delimiterMenu

            if delimiter == .custom {
                TextField("Delimiter", text: $customDelimiter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 72)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }

            Button("Clear", action: onClear)
                .buttonStyle(.borderless)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .pointerCursor()

            Button(action: onPaste) {
                Label("Paste queue", systemImage: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        canPaste
                            ? Color(red: 0.35, green: 0.58, blue: 1.0)
                            : Color.white.opacity(0.12),
                        in: Capsule()
                    )
                    .foregroundStyle(canPaste ? .white : .white.opacity(0.35))
            }
            .buttonStyle(.borderless)
            .disabled(!canPaste)
            .help(canPaste ? "Paste clips in list order, separated by delimiter" : "Select at least 2 clips (⌘-click)")
            .pointerCursor()
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(white: 0.1))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                }
        )
        .onAppear {
            delimiter = Preferences.multiPasteDelimiter
            customDelimiter = Preferences.multiPasteCustomDelimiter
        }
        .onChange(of: delimiter) { _, v in
            Preferences.multiPasteDelimiter = v
        }
        .onChange(of: customDelimiter) { _, v in
            Preferences.multiPasteCustomDelimiter = v
        }
    }

    private var pasteOrderHint: String {
        if orderedItems.count < 2 {
            return "⌘-click to add · ⇧-click for range"
        }
        let labels = orderedItems.prefix(3).map { $0.displaySummary }
        let suffix = orderedItems.count > 3 ? "…" : ""
        return (labels + [suffix]).filter { !$0.isEmpty }.joined(separator: " → ")
    }

    private var delimiterMenu: some View {
        Menu {
            ForEach(MultiPasteDelimiter.allCases) { option in
                Button {
                    delimiter = option
                } label: {
                    HStack {
                        Text(option.displayName)
                        if delimiter == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("Delimiter")
                    .font(.system(size: 12, weight: .medium))
                Text(delimiter.displayName)
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.1), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
