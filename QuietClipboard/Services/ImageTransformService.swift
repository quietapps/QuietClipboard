@preconcurrency import Vision
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Image transforms for image/screenshot clips: resize, format conversion, and on-device
/// background removal. All decoding/encoding is CGImage-based and off-main safe; background
/// removal runs Vision on a dedicated utility queue.
///
/// Keep this file free of app types (models, HUD, save panels) — it is compiled directly
/// into the standalone unit-test bundle, which has no test host. UI flows that wrap these
/// transforms live with their callers (e.g. `ImageActionsMenu`).
enum ImageTransformService {
    private static let queue = DispatchQueue(label: "app.quiet.QuietClipboard.imageTransform", qos: .userInitiated)

    enum ExportFormat: String, CaseIterable, Identifiable {
        case png, jpeg, tiff

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .png: return "PNG"
            case .jpeg: return "JPEG"
            case .tiff: return "TIFF"
            }
        }
        var utType: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .tiff: return .tiff
            }
        }
        var fileExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .tiff: return "tiff"
            }
        }
    }

    enum ResizeOption: Hashable {
        case scale(CGFloat)        // 0 < factor < 1, relative to current pixel size
        case fit(CGFloat)          // longest side capped at N pixels

        var displayName: String {
            switch self {
            case .scale(let f): return "\(Int(f * 100))%"
            case .fit(let px): return "Fit \(Int(px)) px"
            }
        }
    }

    // MARK: - Resize

    /// Returns PNG data resized per `option` (alpha preserved). Nil when the data can't be
    /// decoded or the option wouldn't shrink the image.
    static func resized(_ data: Data, option: ResizeOption) -> Data? {
        guard let cgImage = decode(data) else { return nil }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        guard w > 0, h > 0 else { return nil }

        let scale: CGFloat
        switch option {
        case .scale(let f):
            scale = min(max(f, 0.01), 1.0)
        case .fit(let px):
            scale = min(px / max(w, h), 1.0)
        }
        let tw = max(1, Int((w * scale).rounded()))
        let th = max(1, Int((h * scale).rounded()))
        guard tw < Int(w) || th < Int(h) else { return encode(cgImage, as: .png) }

        guard let scaled = draw(cgImage, width: tw, height: th) else { return nil }
        return encode(scaled, as: .png)
    }

    // MARK: - Convert

    /// Re-encodes image data into `format`. JPEG flattens transparency onto white so
    /// alpha regions don't render black.
    static func converted(_ data: Data, to format: ExportFormat, jpegQuality: CGFloat = 0.9) -> Data? {
        guard var cgImage = decode(data) else { return nil }
        if format == .jpeg, cgImage.alphaInfo != .none, cgImage.alphaInfo != .noneSkipFirst, cgImage.alphaInfo != .noneSkipLast {
            cgImage = flattenedOnWhite(cgImage) ?? cgImage
        }
        return encode(cgImage, as: format, jpegQuality: jpegQuality)
    }

    // MARK: - Background removal

    /// Lifts the foreground subject and returns PNG data with a transparent background.
    /// Returns nil when no subject is found or Vision fails. On-device only.
    static func removingBackground(_ data: Data) async -> Data? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: removeBackgroundSync(data))
            }
        }
    }

    private static func removeBackgroundSync(_ data: Data) -> Data? {
        guard let cgImage = decode(data) else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            NSLog("Background removal failed: \(error)")
            return nil
        }
        guard let result = request.results?.first, !result.allInstances.isEmpty else { return nil }
        do {
            let buffer = try result.generateMaskedImage(
                ofInstances: result.allInstances,
                from: handler,
                croppedToInstancesExtent: false
            )
            let ciImage = CIImage(cvPixelBuffer: buffer)
            let context = CIContext()
            guard let masked = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
            return encode(masked, as: .png)
        } catch {
            NSLog("Background mask generation failed: \(error)")
            return nil
        }
    }

    // MARK: - CGImage helpers

    private static func decode(_ data: Data) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldAllowFloat: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return cgImage
    }

    private static func draw(_ image: CGImage, width: Int, height: Int, background: CGColor? = nil) -> CGImage? {
        let space = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: bitmapInfo.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        if let background {
            ctx.setFillColor(background)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    private static func flattenedOnWhite(_ image: CGImage) -> CGImage? {
        draw(image, width: image.width, height: image.height,
             background: CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    }

    private static func encode(_ image: CGImage, as format: ExportFormat, jpegQuality: CGFloat = 0.9) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, format.utType.identifier as CFString, 1, nil) else { return nil }
        var properties: [CFString: Any] = [:]
        if format == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality] = jpegQuality
        }
        CGImageDestinationAddImage(dest, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
