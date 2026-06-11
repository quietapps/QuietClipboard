import XCTest
import CoreGraphics
import UniformTypeIdentifiers

final class ImageTransformServiceTests: XCTestCase {

    // MARK: - Resize

    func testScaleResizeHalvesPixelDimensions() throws {
        let png = try XCTUnwrap(TestImageFactory.solidPNG(width: 400, height: 200))
        let resized = try XCTUnwrap(ImageTransformService.resized(png, option: .scale(0.5)))
        let image = try XCTUnwrap(TestImageFactory.decode(resized))
        XCTAssertEqual(image.width, 200)
        XCTAssertEqual(image.height, 100)
    }

    func testFitResizeCapsLongestSide() throws {
        let png = try XCTUnwrap(TestImageFactory.solidPNG(width: 400, height: 200))
        let resized = try XCTUnwrap(ImageTransformService.resized(png, option: .fit(100)))
        let image = try XCTUnwrap(TestImageFactory.decode(resized))
        XCTAssertEqual(max(image.width, image.height), 100)
        // Aspect ratio preserved: 400x200 fit to 100 → 100x50.
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 50)
    }

    func testResizeRejectsUndecodableData() {
        XCTAssertNil(ImageTransformService.resized(Data("not an image".utf8), option: .scale(0.5)))
    }

    // MARK: - Convert

    func testConvertToJPEGProducesDecodableJPEG() throws {
        let png = try XCTUnwrap(TestImageFactory.solidPNG(width: 400, height: 200))
        let jpeg = try XCTUnwrap(ImageTransformService.converted(png, to: .jpeg))
        XCTAssertEqual(TestImageFactory.containerType(of: jpeg), UTType.jpeg.identifier)
        let image = try XCTUnwrap(TestImageFactory.decode(jpeg))
        XCTAssertEqual(image.width, 400)
        XCTAssertEqual(image.height, 200)
    }

    func testConvertToTIFFProducesDecodableTIFF() throws {
        let png = try XCTUnwrap(TestImageFactory.solidPNG(width: 400, height: 200))
        let tiff = try XCTUnwrap(ImageTransformService.converted(png, to: .tiff))
        XCTAssertEqual(TestImageFactory.containerType(of: tiff), UTType.tiff.identifier)
        XCTAssertNotNil(TestImageFactory.decode(tiff))
    }

    func testConvertTransparentPNGToJPEGFlattens() throws {
        // Left half opaque, right half fully transparent — forces the flatten-on-white path.
        let png = try XCTUnwrap(TestImageFactory.solidPNG(width: 400, height: 200, opaqueFraction: 0.5))
        let source = try XCTUnwrap(TestImageFactory.decode(png))
        XCTAssertNotEqual(source.alphaInfo, .none, "fixture should carry an alpha channel")

        let jpeg = try XCTUnwrap(ImageTransformService.converted(png, to: .jpeg))
        XCTAssertEqual(TestImageFactory.containerType(of: jpeg), UTType.jpeg.identifier)
        let image = try XCTUnwrap(TestImageFactory.decode(jpeg))
        XCTAssertEqual(image.width, 400)
        XCTAssertEqual(image.height, 200)
    }

    func testConvertRejectsUndecodableData() {
        XCTAssertNil(ImageTransformService.converted(Data([0x00, 0x01, 0x02]), to: .png))
    }

    // MARK: - Background removal

    func testRemoveBackgroundOnFlatColorImageReturnsNil() async throws {
        // A flat solid color has no foreground subject, so the mask request finds no
        // instances and the API contract is a nil result. nil is also the documented
        // fallback when Vision itself fails (e.g. headless runners) — either way this
        // must not crash or return bogus data.
        let png = try XCTUnwrap(TestImageFactory.solidPNG(width: 300, height: 300))
        let result = await ImageTransformService.removingBackground(png)
        XCTAssertNil(result)
    }
}
