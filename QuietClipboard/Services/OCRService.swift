@preconcurrency import Vision
import Foundation
import AppKit

enum OCRService {
    private static let queue = DispatchQueue(label: "app.quiet.QuietClipboard.ocr", qos: .utility)

    /// Recognizes text and reconstructs the visual layout (indentation, column gaps, blank
    /// lines) from the observation bounding boxes, so copied OCR text mirrors the image.
    static func recognizeText(in imageData: Data) async -> String? {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        return await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: recognizeTextSync(on: cgImage))
            }
        }
    }

    /// Whitespace-normalized variant of layout-preserved OCR text: trims each line, collapses
    /// internal runs of spaces/tabs, and caps consecutive blank lines at one.
    static func cleanedText(from layoutText: String) -> String {
        var lines: [String] = []
        var blankRun = 0
        for raw in layoutText.components(separatedBy: .newlines) {
            let collapsed = raw
                .split(whereSeparator: { $0 == " " || $0 == "\t" })
                .joined(separator: " ")
            if collapsed.isEmpty {
                blankRun += 1
                if blankRun == 1, !lines.isEmpty { lines.append("") }
            } else {
                blankRun = 0
                lines.append(collapsed)
            }
        }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    /// Vision types stay on the OCR queue; only `CGImage` is passed across the async boundary.
    private static func recognizeTextSync(on cgImage: CGImage) -> String? {
        var recognized: String?
        let request = VNRecognizeTextRequest { req, _ in
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
            recognized = layoutText(from: observations)
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

    // MARK: - Layout reconstruction

    private struct Segment {
        let text: String
        let box: CGRect  // Vision-normalized: [0,1], origin bottom-left
    }

    private static let maxColumnPad = 240

    private static func layoutText(from observations: [VNRecognizedTextObservation]) -> String? {
        let segments: [Segment] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first,
                  !candidate.string.isEmpty else { return nil }
            return Segment(text: candidate.string, box: obs.boundingBox)
        }
        guard !segments.isEmpty else { return nil }

        // Median glyph width drives the column grid; median height drives blank-line detection.
        let charWidths = segments
            .map { $0.box.width / CGFloat(max(1, $0.text.count)) }
            .sorted()
        let charWidth = max(0.0001, charWidths[charWidths.count / 2])
        let heights = segments.map { $0.box.height }.sorted()
        let medianHeight = max(0.0001, heights[heights.count / 2])

        // Group segments into visual lines: a segment joins the current line when its vertical
        // center sits within the line anchor's band.
        var lines: [[Segment]] = []
        for seg in segments.sorted(by: { $0.box.midY > $1.box.midY }) {
            if let anchor = lines.last?.first,
               abs(seg.box.midY - anchor.box.midY) < max(seg.box.height, anchor.box.height) * 0.6 {
                lines[lines.count - 1].append(seg)
            } else {
                lines.append([seg])
            }
        }

        var rendered: [String] = []
        var previousMidY: CGFloat?
        for line in lines {
            let ordered = line.sorted { $0.box.minX < $1.box.minX }
            guard let first = ordered.first else { continue }

            // Vertical gaps larger than ~1.6 line-heights become blank lines (capped at 2).
            if let prev = previousMidY {
                let extra = Int(((prev - first.box.midY) / (medianHeight * 1.6)).rounded(.down)) - 1
                if extra > 0 {
                    rendered.append(contentsOf: Array(repeating: "", count: min(extra, 2)))
                }
            }
            previousMidY = first.box.midY

            var text = ""
            for (i, seg) in ordered.enumerated() {
                let targetColumn = Int((seg.box.minX / charWidth).rounded())
                let pad = targetColumn - text.count
                let spaces = i == 0 ? max(0, pad) : max(1, pad)
                text += String(repeating: " ", count: min(spaces, maxColumnPad))
                text += seg.text
            }
            rendered.append(text)
        }

        // Strip the common left margin so image padding doesn't become a wall of indentation,
        // while relative alignment between lines is preserved.
        let commonIndent = rendered
            .filter { !$0.isEmpty }
            .map { $0.prefix(while: { $0 == " " }).count }
            .min() ?? 0
        if commonIndent > 0 {
            rendered = rendered.map { $0.isEmpty ? $0 : String($0.dropFirst(commonIndent)) }
        }

        let result = rendered.joined(separator: "\n")
        return result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : result
    }
}
