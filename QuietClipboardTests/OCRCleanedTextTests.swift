import XCTest

/// `OCRService.cleanedText(from:)` is the pure whitespace-normalization layer on top of
/// layout-preserved OCR output — testable without Vision.
final class OCRCleanedTextTests: XCTestCase {

    func testCollapsesInternalWhitespaceRuns() {
        XCTAssertEqual(OCRService.cleanedText(from: "alpha    beta\t\tgamma"),
                       "alpha beta gamma")
    }

    func testTrimsLineEdges() {
        XCTAssertEqual(OCRService.cleanedText(from: "    indented line   "),
                       "indented line")
    }

    func testCapsConsecutiveBlankLinesAtOne() {
        XCTAssertEqual(OCRService.cleanedText(from: "one\n\n\n\ntwo"),
                       "one\n\ntwo")
    }

    func testDropsLeadingAndTrailingBlankLines() {
        XCTAssertEqual(OCRService.cleanedText(from: "\n\nbody\n\n\n"),
                       "body")
    }

    func testPreservesSingleParagraphBreak() {
        XCTAssertEqual(OCRService.cleanedText(from: "first paragraph\n\nsecond paragraph"),
                       "first paragraph\n\nsecond paragraph")
    }

    func testMultilineDocumentNormalizesAsAWhole() {
        let layout = """
          Title   Line\t

        \t
            body  starts here

        """
        XCTAssertEqual(OCRService.cleanedText(from: layout),
                       "Title Line\n\nbody starts here")
    }
}
