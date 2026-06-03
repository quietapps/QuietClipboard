import SwiftUI

struct SensitiveContentGate<Content: View>: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let item: ClipboardItem
    var compact: Bool = false
    @ViewBuilder var content: () -> Content

    private var isRedacted: Bool {
        item.isSensitive && !coordinator.isSensitiveRevealed(item.id)
    }

    var body: some View {
        if isRedacted {
            SensitiveRedactedPanel(compact: compact) {
                coordinator.revealSensitive(item.id)
            }
        } else {
            content()
        }
    }
}

struct SensitiveRedactedPanel: View {
    let onReveal: () -> Void
    var compact: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
            if !compact {
                decorativeBars
            }
            VStack(spacing: compact ? 4 : 8) {
                Image(systemName: "lock.fill")
                    .font(compact ? .caption : .title3)
                    .foregroundStyle(.secondary)
                if !compact {
                    Text("Sensitive content hidden")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Reveal", action: onReveal)
                    .buttonStyle(.borderedProminent)
                    .controlSize(compact ? .small : .regular)
            }
            .padding(compact ? 6 : 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sensitive content hidden")
        .accessibilityHint("Double tap to reveal")
        .accessibilityAddTraits(.isButton)
    }

    private var decorativeBars: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: CGFloat([120, 200, 160, 90][i]), height: 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .blur(radius: 6)
        .allowsHitTesting(false)
    }
}

struct SensitiveClipLabel: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    let item: ClipboardItem
    var font: Font = .body
    var lineLimit: Int = 2
    var monospaced: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if item.isSensitive && !coordinator.isSensitiveRevealed(item.id) {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            labelText
        }
    }

    @ViewBuilder
    private var labelText: some View {
        let title = Text(SensitiveRedaction.displayTitle(
            for: item,
            isRevealed: coordinator.isSensitiveRevealed(item.id)
        ))
        .lineLimit(lineLimit)
        if monospaced {
            title.font(font).monospaced()
        } else {
            title.font(font)
        }
    }
}

enum SensitiveRedaction {
    static func displayTitle(for item: ClipboardItem, isRevealed: Bool) -> String {
        if item.isSensitive, !isRevealed {
            return "Sensitive content"
        }
        return item.title ?? item.textContent ?? "Untitled"
    }
}
