import AppKit
import SwiftUI

/// Horizontal chip bar: trackpad scroll, click-drag to pan, optional scroller (macOS).
struct HorizontalScrollBar<Content: View>: NSViewRepresentable {
    let content: Content
    var barHeight: CGFloat = 34
    var showsHorizontalScroller: Bool = false

    init(barHeight: CGFloat = 34,
         showsHorizontalScroller: Bool = false,
         @ViewBuilder content: () -> Content) {
        self.barHeight = barHeight
        self.showsHorizontalScroller = showsHorizontalScroller
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        context.coordinator.barHeight = barHeight
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = showsHorizontalScroller
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.horizontalScrollElasticity = .automatic
        scroll.verticalScrollElasticity = .none
        scroll.usesPredominantAxisScrolling = true

        let clip = NSClipView()
        clip.drawsBackground = false
        scroll.contentView = clip

        let hosting = NSHostingView(rootView: AnyView(content))
        hosting.translatesAutoresizingMaskIntoConstraints = true
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
        context.coordinator.barHeight = barHeight
        scroll.hasHorizontalScroller = showsHorizontalScroller
        context.coordinator.hosting?.rootView = AnyView(content)
        DispatchQueue.main.async {
            context.coordinator.layoutDocument()
        }
    }

    final class Coordinator: NSObject, NSGestureRecognizerDelegate {
        weak var scrollView: NSScrollView?
        weak var hosting: NSHostingView<AnyView>?
        var barHeight: CGFloat = 34
        private var isDragging = false

        var canScrollHorizontally: Bool {
            guard let scroll = scrollView else { return false }
            let docW = scroll.documentView?.frame.width ?? 0
            let clipW = scroll.contentView.bounds.width
            return docW > clipW + 2
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
            guard canScrollHorizontally,
                  let pan = gestureRecognizer as? NSPanGestureRecognizer,
                  let scroll = scrollView else { return false }
            let velocity = pan.velocity(in: scroll)
            return abs(velocity.x) >= abs(velocity.y)
        }

        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            guard let scroll = scrollView, canScrollHorizontally else { return }

            switch gesture.state {
            case .began:
                isDragging = true
                NSCursor.closedHand.push()
            case .ended, .cancelled, .failed:
                if isDragging {
                    isDragging = false
                    NSCursor.pop()
                }
            default:
                break
            }

            let deltaX = gesture.translation(in: scroll).x
            gesture.setTranslation(.zero, in: scroll)

            var origin = scroll.contentView.bounds.origin
            origin.x -= deltaX
            let maxX = max(
                0,
                (scroll.documentView?.frame.width ?? 0) - scroll.contentView.bounds.width
            )
            origin.x = max(0, min(origin.x, maxX))
            scroll.contentView.scroll(to: origin)
            scroll.reflectScrolledClipView(scroll.contentView)
        }

        func layoutDocument() {
            guard let scroll = scrollView, let hosting else { return }

            hosting.invalidateIntrinsicContentSize()

            let clipHeight = barHeight
            hosting.frame = NSRect(x: 0, y: 0, width: 10_000, height: clipHeight)
            hosting.layoutSubtreeIfNeeded()
            let contentWidth = max(ceil(hosting.fittingSize.width) + 8, 1)
            let clipWidth = max(scroll.contentView.bounds.width, scroll.bounds.width, 1)
            let docWidth = max(contentWidth, clipWidth)

            hosting.frame = NSRect(x: 0, y: 0, width: docWidth, height: clipHeight)
            scroll.documentView = hosting
            scroll.documentView?.frame = hosting.frame

            let maxX = max(0, docWidth - clipWidth)
            var origin = scroll.contentView.bounds.origin
            origin.x = min(origin.x, maxX)
            origin.y = 0
            scroll.contentView.scroll(to: origin)
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }
}
