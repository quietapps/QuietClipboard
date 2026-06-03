import AppKit
import SwiftUI

/// Horizontal chip bar: trackpad/wheel scroll + click-drag to pan (macOS).
struct HorizontalScrollBar<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.horizontalScrollElasticity = .automatic
        scroll.verticalScrollElasticity = .none
        scroll.scrollerStyle = .overlay

        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = hosting

        context.coordinator.scrollView = scroll
        context.coordinator.hosting = hosting

        let pan = NSPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.buttonMask = 0x1
        pan.delegate = context.coordinator
        scroll.addGestureRecognizer(pan)

        DispatchQueue.main.async {
            context.coordinator.layoutDocument()
        }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.hosting?.rootView = AnyView(content)
        DispatchQueue.main.async {
            context.coordinator.layoutDocument()
        }
    }

    final class Coordinator: NSObject, NSGestureRecognizerDelegate {
        weak var scrollView: NSScrollView?
        weak var hosting: NSHostingView<AnyView>?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? NSPanGestureRecognizer,
                  let scroll = scrollView else { return false }
            let velocity = pan.velocity(in: scroll)
            return abs(velocity.x) > abs(velocity.y)
        }

        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            guard let scroll = scrollView else { return }
            let deltaX = gesture.translation(in: scroll).x
            gesture.setTranslation(.zero, in: scroll)

            var origin = scroll.contentView.bounds.origin
            origin.x -= deltaX
            let maxX = max(
                0,
                (scroll.documentView?.frame.width ?? 0) - scroll.contentView.bounds.width
            )
            origin.x = max(0, min(origin.x, maxX))
            scroll.contentView.setBoundsOrigin(origin)
            scroll.reflectScrolledClipView(scroll.contentView)
        }

        func layoutDocument() {
            guard let scroll = scrollView, let hosting else { return }
            let barHeight: CGFloat = 34
            hosting.layoutSubtreeIfNeeded()
            let width = max(hosting.fittingSize.width, scroll.bounds.width)
            hosting.frame = NSRect(x: 0, y: 0, width: width, height: barHeight)
            scroll.documentView = hosting
            scroll.documentView?.frame = hosting.frame
        }
    }
}
