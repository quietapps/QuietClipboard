import XCTest

final class ColorParsingTests: XCTestCase {

    // MARK: - isColorString

    func testAcceptsSupportedColorSyntaxes() {
        let positives = [
            "#FF0000",
            "#f00",
            "#FF000080",          // 8-digit hex with alpha
            "ff8800",             // bare hex, no hash
            "rgb(255, 0, 0)",
            "rgba(0,128,255,0.5)",
            "RGB(1, 2, 3)",       // case-insensitive
            "hsl(120, 100%, 50%)",
            "hsla(0, 0%, 100%, 1)",
            "  #abc  "            // surrounding whitespace trimmed
        ]
        for s in positives {
            XCTAssertTrue(ColorParsing.isColorString(s), "expected '\(s)' to be a color")
        }
    }

    func testRejectsNonColors() {
        let negatives = [
            "hello world",
            "#GGGGGG",            // not hex digits
            "#ff00",              // 4 digits: not 3/6/8
            "rgb(255, 0)",        // missing component
            "hsl(120, 100, 50)",  // missing % signs
            "rgb(255,0,0) trailing",
            String(repeating: "a", count: 40)  // over the 32-char gate
        ]
        for s in negatives {
            XCTAssertFalse(ColorParsing.isColorString(s), "expected '\(s)' to be rejected")
        }
    }

    // MARK: - hexFrom normalization

    func testHexNormalization() {
        XCTAssertEqual(ColorParsing.hexFrom("#f00"), "#FF0000")      // short hex expands
        XCTAssertEqual(ColorParsing.hexFrom("#AaBbCc"), "#AABBCC")   // uppercased
        XCTAssertEqual(ColorParsing.hexFrom("ff8800"), "#FF8800")    // hash added
        XCTAssertEqual(ColorParsing.hexFrom("#ff000080"), "#FF000080")  // alpha byte kept
        XCTAssertEqual(ColorParsing.hexFrom("  #fff  "), "#FFFFFF")  // trimmed + expanded
    }

    func testHexFromRGBSyntax() {
        XCTAssertEqual(ColorParsing.hexFrom("rgb(255, 0, 0)"), "#FF0000")
        XCTAssertEqual(ColorParsing.hexFrom("rgb(0,128,255)"), "#0080FF")
        XCTAssertEqual(ColorParsing.hexFrom("rgba(0, 128, 255, 0.5)"), "#0080FF")  // alpha dropped
        XCTAssertEqual(ColorParsing.hexFrom("rgb(300, 0, 0)"), "#FF0000")          // clamped to 255
    }

    func testHexFromHSLSyntax() {
        XCTAssertEqual(ColorParsing.hexFrom("hsl(0, 100%, 50%)"), "#FF0000")
        XCTAssertEqual(ColorParsing.hexFrom("hsl(120, 100%, 50%)"), "#00FF00")
        XCTAssertEqual(ColorParsing.hexFrom("hsl(240, 100%, 50%)"), "#0000FF")
        XCTAssertEqual(ColorParsing.hexFrom("hsl(0, 0%, 50%)"), "#808080")  // achromatic path
        XCTAssertEqual(ColorParsing.hexFrom("hsla(120, 100%, 50%, 0.3)"), "#00FF00")
    }

    func testEquivalentSyntaxesNormalizeToSameHex() {
        // The whole point of hexFrom: dedup across representations of the same color.
        let red = ["#f00", "#FF0000", "rgb(255,0,0)", "hsl(0, 100%, 50%)"]
            .map { ColorParsing.hexFrom($0) }
        XCTAssertEqual(Set(red), ["#FF0000"])
    }

    func testHexFromReturnsNilForNonColors() {
        XCTAssertNil(ColorParsing.hexFrom("not a color"))
        XCTAssertNil(ColorParsing.hexFrom("rgb(1,2)"))
        XCTAssertNil(ColorParsing.hexFrom(""))
    }
}
