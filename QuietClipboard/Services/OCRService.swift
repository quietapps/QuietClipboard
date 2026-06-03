import Foundation
@preconcurrency import Vision
import AppKit

enum OCRService {
    private static let queue = DispatchQueue(label: "app.quiet.QuietClipboard.ocr", qos: .utility)

    static func recognizeText(in imageData: Data) async -> String? {
        guard let image = NSImage(data: imageData),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            let image = cg
            queue.async {
                continuation.resume(returning: recognizeTextSync(on: image))
            }
        }
    }

    /// Runs Vision on the OCR queue; only `CGImage` crosses the async boundary.
    private static func recognizeTextSync(on cgImage: CGImage) -> String? {
        var recognized: String?
        let request = VNRecognizeTextRequest { req, _ in
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
            recognized = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            NSLog("OCR failed: \(error)")
            return nil
        }
        guard let recognized, !recognized.isEmpty else { return nil }
        return recognized
    }
}
