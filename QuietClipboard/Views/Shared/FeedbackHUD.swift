import AppKit
import SwiftUI

/// Tiny capsule HUD — fixed-size non-activating floating panel. Deliberately minimal: no
/// pre-measure, no animation, no `sizingOptions` callbacks. Earlier dynamic-sizing version
/// could hang the main thread under SwiftUI layout cascades.
@MainActor
final class FeedbackHUD {
    static let shared = FeedbackHUD()

    private static let size = NSSize(width: 320, height: 44)

    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private var action: (() -> Void)?

    func show(_ message: String,
              systemImage: String,
              isWarning: Bool = false,
              duration: TimeInterval = 1.1,
              onClick: (() -> Void)? = nil) {
        action = onClick
        let p = panel ?? makePanel()
        panel = p

        // Replace root view in place rather than swapping NSHostingController each call —
        // avoids repeated SwiftUI host construction on rapid copy/paste sequences.
        let view = FeedbackHUDView(message: message,
                                   systemImage: systemImage,
                                   isWarning: isWarning) { [weak self] in
            self?.action?()
            self?.dismiss()
        }
        if let host = p.contentViewController as? NSHostingController<FeedbackHUDView> {
            host.rootView = view
        } else {
            p.contentViewController = NSHostingController(rootView: view)
        }
        position(p)
        p.orderFrontRegardless()

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func dismiss() {
        hideWork?.cancel()
        hideWork = nil
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = false
        p.hidesOnDeactivate = false
        p.ignoresMouseEvents = false
        return p
    }

    private func position(_ p: NSPanel) {
        // Top-center pill, just under the menu bar (visibleFrame already excludes the menu bar).
        // Picks the screen the menu bar is on — `NSScreen.main` returns the screen with the
        // currently-focused window, which is what the user is looking at.
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let v = screen?.visibleFrame else { return }
        p.setFrame(
            NSRect(x: v.midX - Self.size.width / 2,
                   y: v.maxY - Self.size.height - 6,
                   width: Self.size.width,
                   height: Self.size.height),
            display: false
        )
    }
}

private struct FeedbackHUDView: View {
    let message: String
    let systemImage: String
    let isWarning: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isWarning ? Color.orange : Color.accentColor)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture { onTap() }
    }
}
