import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Deterministic in-memory image fixtures. Everything renders offscreen — tests never read
/// the pasteboard, the screen, or any file on disk, so they stay safe to run on a machine
/// where the real app is installed.
enum TestImageFactory {

    /// Solid-fill RGBA bitmap encoded as PNG. `opaqueFraction < 1` leaves the right portion
    /// fully transparent so JPEG flatten paths can be exercised.
    static func solidPNG(width: Int, height: Int, opaqueFraction: CGFloat = 1.0) -> Data? {
        guard let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        let opaqueWidth = CGFloat(width) * min(max(opaqueFraction, 0), 1)
        ctx.fill(CGRect(x: 0, y: 0, width: opaqueWidth, height: CGFloat(height)))
        guard let image = ctx.makeImage() else { return nil }
        return pngData(image)
    }

    /// Monospaced black text on a white background, encoded as PNG. Points use the
    /// bottom-left origin of the unflipped bitmap context. Monospace keeps glyph columns
    /// predictable so OCR layout reconstruction (indent/column maths) is testable.
    static func textPNG(width: Int, height: Int, fontSize: CGFloat,
                        runs: [(text: String, x: CGFloat, y: CGFloat)]) -> Data? {
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: width, pixelsHigh: height,
                                         bitsPerSample: 8, samplesPerPixel: 4,
                                         hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor.black
        ]
        for run in runs {
            NSAttributedString(string: run.text, attributes: attributes)
                .draw(at: NSPoint(x: run.x, y: run.y))
        }
        ctx.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    static func pngData(_ image: CGImage) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Container UTI of encoded image data (e.g. `public.jpeg`), for asserting the format
    /// actually changed rather than just that bytes came back.
    static func containerType(of data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceGetType(source) as String?
    }
}
