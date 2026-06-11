import XCTest

/// End-to-end check of `OCRService.recognizeText(in:)` — Vision recognition plus the layout
/// reconstruction (line ordering, indentation, column gaps) — against an image rendered
/// in-memory. Assertions target stable dictionary words and relative structure, not exact
/// strings, because Vision output can vary slightly across OS versions.
final class OCRLayoutIntegrationTests: XCTestCase {

    func testRecognizesWordsAndReconstructsLayout() async throws {
        // 900x300 white canvas, 28pt monospaced black text (bottom-left origin):
        //   top line at the left margin, second line clearly indented (~220px deeper),
        //   bottom row split into two columns with a ~430px gap.
        let png = try XCTUnwrap(TestImageFactory.textPNG(
            width: 900, height: 300, fontSize: 28,
            runs: [
                (text: "HELLO WORLD", x: 20, y: 220),
                (text: "GOODBYE MOON", x: 240, y: 140),
                (text: "LEFT", x: 20, y: 60),
                (text: "RIGHT", x: 640, y: 60)
            ]), "fixture rendering failed")

        let recognized = await OCRService.recognizeText(in: png)
        let text = try XCTUnwrap(recognized, "Vision returned no text for a high-contrast rendered image")
        let upper = text.uppercased()

        for word in ["HELLO", "WORLD", "GOODBYE", "MOON", "LEFT", "RIGHT"] {
            XCTAssertTrue(upper.contains(word), "missing '\(word)' in OCR output:\n\(text)")
        }

        let lines = upper.components(separatedBy: "\n")
        let helloLine = try XCTUnwrap(lines.firstIndex { $0.contains("HELLO") })
        let goodbyeLine = try XCTUnwrap(lines.firstIndex { $0.contains("GOODBYE") })
        let leftLine = try XCTUnwrap(lines.firstIndex { $0.contains("LEFT") })

        // Lines come out top-to-bottom.
        XCTAssertLessThan(helloLine, goodbyeLine, "top line should precede indented line:\n\(text)")
        XCTAssertLessThan(goodbyeLine, leftLine, "indented line should precede column row:\n\(text)")

        // Common left margin is stripped, so the leftmost line has no indent while the
        // visually indented line keeps leading spaces.
        XCTAssertFalse(lines[helloLine].hasPrefix(" "),
                       "leftmost line should not be indented:\n\(text)")
        XCTAssertTrue(lines[goodbyeLine].hasPrefix("  "),
                      "indented line should keep leading spaces:\n\(text)")

        // The two-column row stays on one reconstructed line, with the column gap rendered
        // as a run of spaces rather than collapsing to a single separator.
        let row = lines[leftLine]
        XCTAssertTrue(row.contains("RIGHT"), "columns should share one line:\n\(text)")
        XCTAssertNotNil(row.range(of: #"LEFT {2,}.*RIGHT"#, options: .regularExpression),
                        "column gap should survive as multiple spaces:\n\(text)")
    }
}
