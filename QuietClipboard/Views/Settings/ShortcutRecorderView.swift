import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ShortcutRecorderView: View {
    @Binding var combo: KeyCombo?
    @State private var recording = false

    var body: some View {
        Button(action: { recording.toggle() }) {
            HStack {
                if recording {
                    Text("Press shortcut…")
                        .foregroundStyle(.secondary)
                        .italic()
                } else if let combo {
                    Text(combo.displayString)
                        .font(.system(.body, design: .monospaced))
                } else {
                    Text("Not set").foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 120)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(recording ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor),
                        in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(recording ? Color.accentColor : Color.secondary.opacity(0.3))
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
