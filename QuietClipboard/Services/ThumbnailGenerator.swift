import AppKit

enum ThumbnailGenerator {
    static let maxDimension: CGFloat = 200

    static func thumbnail(forImageData data: Data, maxDimension limit: CGFloat = 200) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(limit / size.width, limit / size.height, 1.0)
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let thumb = NSImage(size: target)
        thumb.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: target),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy,
                   fraction: 1.0)
        thumb.unlockFocus()
        guard let tiff = thumb.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// Square favicon tile with inset icon — avoids oversized opaque blocks in list/preview.
    static func faviconTile(from iconData: Data, canvasSize: CGFloat = 64) -> Data? {
        guard let source = NSImage(data: iconData) else { return nil }
        let srcSize = source.size
        guard srcSize.width > 0, srcSize.height > 0 else { return nil }

        let canvas = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
        canvas.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        let bg = NSRect(origin: .zero, size: canvas.size)
        NSColor.controlBackgroundColor.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: bg, xRadius: canvasSize * 0.2, yRadius: canvasSize * 0.2).fill()

        let inset = canvasSize * 0.18
        let box = NSRect(x: inset, y: inset, width: canvasSize - inset * 2, height: canvasSize - inset * 2)
        let scale = min(box.width / srcSize.width, box.height / srcSize.height)
        let drawW = srcSize.width * scale
        let drawH = srcSize.height * scale
        let drawRect = NSRect(
            x: box.midX - drawW / 2,
            y: box.midY - drawH / 2,
            width: drawW,
            height: drawH
        )
        source.draw(in: drawRect,
                    from: NSRect(origin: .zero, size: srcSize),
                    operation: .sourceOver,
                    fraction: 1.0)

        canvas.unlockFocus()
        guard let tiff = canvas.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
