import Foundation
import Vision
import AppKit

enum OCRService {
    static func recognizeText(in imageData: Data) async -> String? {
        guard let image = NSImage(data: imageData),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { req, _ in
                let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                cont.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .utility).async {
                do {
                    try handler.perform([request])
                } catch {
                    NSLog("OCR failed: \(error)")
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
