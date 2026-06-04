import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ThumbnailGenerator {
    static let maxDimension: CGFloat = 200

    // CGImage-based — thread-safe, no NSImage.lockFocus required
    static func thumbnail(forImageData data: Data, maxDimension limit: CGFloat = 200) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldAllowFloat: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        guard w > 0, h > 0 else { return nil }

        let scale = min(limit / w, limit / h, 1.0)
        let tw = max(1, Int(w * scale))
        let th = max(1, Int(h * scale))

        let space = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = CGContext(data: nil, width: tw, height: th,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: bitmapInfo.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: tw, height: th))
        guard let thumb = ctx.makeImage() else { return nil }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, thumb, [kCGImageDestinationLossyCompressionQuality: 0.80] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    /// Re-encodes arbitrary image data (PNG/TIFF/JPEG) to PNG, optionally downscaling so neither
    /// dimension exceeds `maxDimension`. Returns nil if the data can't be decoded. Off-main safe.
    static func pngData(forImageData data: Data, maxDimension limit: CGFloat? = nil) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldAllowFloat: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        guard w > 0, h > 0 else { return nil }

        let scale = limit.map { min($0 / w, $0 / h, 1.0) } ?? 1.0
        var image = cgImage
        if scale < 1.0 {
            let tw = max(1, Int(w * scale))
            let th = max(1, Int(h * scale))
            let space = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let ctx = CGContext(data: nil, width: tw, height: th,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: bitmapInfo.rawValue) else { return nil }
            ctx.interpolationQuality = .high
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: tw, height: th))
            guard let scaled = ctx.makeImage() else { return nil }
            image = scaled
        }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    /// Pixel dimensions of image data without a full decode. Off-main safe.
    static func pixelSize(forImageData data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0 else { return nil }
        return CGSize(width: w, height: h)
    }

    /// Square favicon tile — CGContext-based, off-main safe
    static func faviconTile(from iconData: Data, canvasSize: CGFloat = 64) -> Data? {
        guard let source = CGImageSourceCreateWithData(iconData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }

        let cs = Int(canvasSize)
        let space = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = CGContext(data: nil, width: cs, height: cs,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: bitmapInfo.rawValue) else { return nil }
        ctx.interpolationQuality = .high

        let inset = canvasSize * 0.18
        let boxW = canvasSize - inset * 2
        let boxH = canvasSize - inset * 2
        let imgW = CGFloat(cgImage.width)
        let imgH = CGFloat(cgImage.height)
        guard imgW > 0, imgH > 0 else { return nil }
        let s = min(boxW / imgW, boxH / imgH)
        let dw = imgW * s, dh = imgH * s
        let dx = (canvasSize - dw) / 2, dy = (canvasSize - dh) / 2
        ctx.draw(cgImage, in: CGRect(x: dx, y: dy, width: dw, height: dh))

        guard let tile = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, tile, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
