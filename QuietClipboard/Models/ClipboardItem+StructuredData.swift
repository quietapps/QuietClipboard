import Foundation

extension ClipboardItem {
    var structuredDataMatch: StructuredDataMatch? {
        if let json = structuredDataJSON,
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(StructuredDataMatch.self, from: data) {
            return decoded
        }
        guard let text = textContent else { return nil }
        return StructuredDataDetector.primaryMatch(in: text)
    }

    var structuredDataMatches: [StructuredDataMatch] {
        if let primary = structuredDataMatch { return [primary] }
        guard let text = textContent else { return [] }
        return StructuredDataDetector.allMatches(in: text)
    }

    func applyStructuredDataDetection() {
        guard let text = textContent else {
            structuredDataJSON = nil
            return
        }
        // Single-line primary detection only; skip huge blobs to avoid regex edge cases.
        guard text.count <= 32_768 else {
            structuredDataJSON = nil
            return
        }
        guard let match = StructuredDataDetector.primaryMatch(in: text) else {
            structuredDataJSON = nil
            return
        }
        if let data = try? JSONEncoder().encode(match),
           let json = String(data: data, encoding: .utf8) {
            structuredDataJSON = json
        }
    }
}
