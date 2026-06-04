import AppKit
import SwiftUI

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class FloatingPanelController<Content: View>: NSObject, NSWindowDelegate {
    private var panel: KeyablePanel?
    private let content: () -> Content
    private let defaultSize: NSSize
    private let minSize: NSSize
    private(set) var priorApp: NSRunningApplication?
    private var globalMouseMonitor: Any?
    private var appResignObserver: Any?
    var onWillShow: (() -> Void)?

    init(width: CGFloat, height: CGFloat, minWidth: CGFloat = 520, minHeight: CGFloat = 320, @ViewBuilder content: @escaping () -> Content) {
        self.defaultSize = NSSize(width: width, height: height)
        self.minSize = NSSize(width: minWidth, height: minHeight)
        self.content = content
    }

    private var currentSize: NSSize {
        let stored = MainActor.assumeIsolated { Preferences.quickSearchLastSize }
        guard let s = stored else { return defaultSize }
        return NSSize(width: max(minSize.width, s.width), height: max(minSize.height, s.height))
    }

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func prebuild() {
        if panel == nil { build() }
    }

    func show() {
        if panel == nil { build() }
        priorApp = NSWorkspace.shared.frontmostApplication
        // Activate early so macOS processes the app-switch in parallel with our setup.
        NSApp.activate(ignoringOtherApps: true)
        guard let panel else { return }
        positionPanel(panel)
        onWillShow?()
        panel.makeKeyAndOrderFront(nil)
        installDismissMonitors()
    }

    func hide() {
        removeDismissMonitors()
        if let frame = panel?.frame {
            MainActor.assumeIsolated {
                Preferences.quickSearchLastOrigin = frame.origin
                Preferences.quickSearchLastSize = frame.size
            }
        }
        panel?.orderOut(nil)
        // Panel kept alive for instant reopen — no rebuild overhead on next show.
    }

    func resetSize() {
        MainActor.assumeIsolated { Preferences.quickSearchLastSize = nil }
        guard let panel else { return }
        var frame = panel.frame
        let topLeftY = frame.maxY
        frame.size = defaultSize
        frame.origin.y = topLeftY - defaultSize.height
        panel.setFrame(frame, display: true, animate: panel.isVisible)
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    private func installDismissMonitors() {
        removeDismissMonitors()
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self, let panel = self.panel, panel.isVisible else { return }
            if panel.frame.contains(NSEvent.mouseLocation) { return }
            self.hide()
        }
        appResignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeDismissMonitors() {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m); globalMouseMonitor = nil }
        if let o = appResignObserver { NotificationCenter.default.removeObserver(o); appResignObserver = nil }
    }

    private func build() {
        let host = NSHostingController(rootView: content())
        let initialSize = currentSize
        let p = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered, defer: false
        )
        p.becomesKeyOnlyIfNeeded = false
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.isMovable = true
        p.isMovableByWindowBackground = true
        p.hasShadow = true
        p.backgroundColor = .clear
        p.isOpaque = false
        p.ignoresMouseEvents = false
        p.hidesOnDeactivate = false
        p.minSize = minSize
        p.contentView = host.view
        p.contentViewController = host
        p.delegate = self
        p.standardWindowButton(.closeButton)?.isHidden = true
        p.standardWindowButton(.miniaturizeButton)?.isHidden = true
        p.standardWindowButton(.zoomButton)?.isHidden = true
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        self.panel = p
    }

    private func positionPanel(_ p: NSPanel) {
        let size = currentSize
        let origin = quickSearchOrigin(for: size)
        p.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func quickSearchOrigin(for size: NSSize) -> NSPoint {
        let placement = MainActor.assumeIsolated { Preferences.quickSearchPlacement }
        func centered(in screen: NSScreen) -> NSPoint {
            let v = screen.visibleFrame
            return NSPoint(x: v.midX - size.width / 2,
                           y: v.midY - size.height / 2 + 100)
        }
        func screen(containing point: NSPoint) -> NSScreen {
            NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main!
        }
        func clamp(_ origin: NSPoint, in screen: NSScreen) -> NSPoint {
            let v = screen.visibleFrame
            let x = max(v.minX + 8, min(origin.x, v.maxX - size.width - 8))
            let y = max(v.minY + 8, min(origin.y, v.maxY - size.height - 8))
            return NSPoint(x: x, y: y)
        }
        switch placement {
        case .cursor:
            let p = NSEvent.mouseLocation
            let s = screen(containing: p)
            // Frame origin is bottom-left; place top-left of panel at cursor.
            let origin = NSPoint(x: p.x, y: p.y - size.height)
            return clamp(origin, in: s)
        case .menuIcon:
            if let frame = menuIconScreenFrame() {
                let s = screen(containing: NSPoint(x: frame.midX, y: frame.midY))
                let origin = NSPoint(x: frame.midX - size.width / 2,
                                     y: frame.minY - size.height - 6)
                return clamp(origin, in: s)
            }
            return centered(in: NSScreen.main ?? NSScreen.screens[0])
        case .windowCenter:
            if let r = frontmostWindowFrame() {
                let s = screen(containing: NSPoint(x: r.midX, y: r.midY))
                return clamp(NSPoint(x: r.midX - size.width / 2,
                                     y: r.midY - size.height / 2), in: s)
            }
            return centered(in: NSScreen.main ?? NSScreen.screens[0])
        case .screenCenterActive:
            let s = screen(containing: NSEvent.mouseLocation)
            return centered(in: s)
        case .screenCenterChosen:
            let id = MainActor.assumeIsolated { Preferences.quickSearchDisplayID }
            let target = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id } ?? NSScreen.main ?? NSScreen.screens[0]
            return centered(in: target)
        case .lastPosition:
            let last = MainActor.assumeIsolated { Preferences.quickSearchLastOrigin }
            if let p = last {
                let s = screen(containing: NSPoint(x: p.x + size.width/2, y: p.y + size.height/2))
                return clamp(NSPoint(x: p.x, y: p.y), in: s)
            }
            return centered(in: NSScreen.main ?? NSScreen.screens[0])
        }
    }

    private func menuIconScreenFrame() -> CGRect? {
        for w in NSApp.windows {
            let cls = String(describing: type(of: w))
            if cls.contains("StatusBar") && w.isVisible {
                return w.frame
            }
        }
        return nil
    }

    private func frontmostWindowFrame() -> CGRect? {
        guard let app = priorApp else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let winObj = winRef else { return nil }
        let win = winObj as! AXUIElement
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef)
        AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef)
        guard let posObj = posRef, let sizeObj = sizeRef else { return nil }
        var pos = CGPoint.zero
        var sz = CGSize.zero
        AXValueGetValue(posObj as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeObj as! AXValue, .cgSize, &sz)
        let screenMaxY = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
        let cocoaY = screenMaxY - pos.y - sz.height
        return CGRect(x: pos.x, y: cocoaY, width: sz.width, height: sz.height)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    deinit {
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m) }
        if let o = appResignObserver { NotificationCenter.default.removeObserver(o) }
    }
}
