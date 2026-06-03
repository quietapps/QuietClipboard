import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ShortcutRecorderView: View {
    @Binding var combo: KeyCombo?
    @State private var recording = false
    @Environment(\.settingsDarkChrome) private var darkChrome

    var body: some View {
        Button(action: { recording.toggle() }) {
            HStack {
                if recording {
                    Text("Press shortcut…")
                        .foregroundStyle(darkChrome ? SettingsChrome.secondaryText : .secondary)
                        .italic()
                } else if let combo {
                    Text(combo.displayString)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(darkChrome ? SettingsChrome.primaryText : .primary)
                } else {
                    Text("Not set")
                        .foregroundStyle(darkChrome ? SettingsChrome.secondaryText : .secondary)
                }
            }
            .frame(minWidth: 120)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(chipBackground, in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(chipStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .background(
            Recorder(isRecording: $recording) { code, modifiers in
                self.combo = KeyCombo(keyCode: code, modifiers: modifiers)
                self.recording = false
            }
        )
    }

    private var chipBackground: Color {
        if recording {
            return Color.accentColor.opacity(0.25)
        }
        return darkChrome ? SettingsChrome.controlFill : Color(nsColor: .controlBackgroundColor)
    }

    private var chipStroke: Color {
        if recording { return Color.accentColor }
        return darkChrome ? SettingsChrome.groupedStroke : Color.secondary.opacity(0.3)
    }
}

private struct Recorder: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onRecord: (UInt32, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> RecorderView {
        let v = RecorderView()
        v.onRecord = { c, m in
            onRecord(c, m)
        }
        return v
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.isRecording = isRecording
    }
}

private final class RecorderView: NSView {
    var onRecord: ((UInt32, NSEvent.ModifierFlags) -> Void)?
    var isRecording: Bool = false {
        didSet {
            if isRecording { installMonitor() } else { removeMonitor() }
        }
    }
    private var monitor: Any?

    private func installMonitor() {
        if monitor != nil { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty else { return event }
            self.onRecord?(UInt32(event.keyCode), mods)
            self.removeMonitor()
            self.isRecording = false
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }

    deinit { removeMonitor() }
}
