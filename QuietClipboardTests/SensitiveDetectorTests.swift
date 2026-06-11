import XCTest

final class SensitiveDetectorTests: XCTestCase {

    // MARK: - Positives

    func testDetectsOpenAIKey() {
        XCTAssertTrue(SensitiveDetector.isSensitive(
            "here is the key: sk-proj-Tk29xVZmQ4LbN8wRfA61PdCe", isConcealed: false))
    }

    func testDetectsAWSAccessKey() {
        XCTAssertTrue(SensitiveDetector.isSensitive(
            "aws_access_key_id = AKIAIOSFODNN7EXAMPLE", isConcealed: false))
    }

    func testDetectsGitHubPersonalAccessToken() {
        XCTAssertTrue(SensitiveDetector.isSensitive(
            "ghp_AbCdEfGhIjKlMnOpQrStUvWxYz0123456789", isConcealed: false))
    }

    func testDetectsJWT() {
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
            + ".eyJzdWIiOiIxMjM0NTY3ODkwIn0"
            + ".dBjftJeZ4CVPmB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        XCTAssertTrue(SensitiveDetector.isSensitive(jwt, isConcealed: false))
    }

    func testDetectsRSAPrivateKeyHeader() {
        XCTAssertTrue(SensitiveDetector.isSensitive(
            "-----BEGIN RSA PRIVATE KEY-----", isConcealed: false))
    }

    func testDetectsSSHEd25519PublicKey() {
        XCTAssertTrue(SensitiveDetector.isSensitive(
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB3KqzX0vQ2m build@host", isConcealed: false))
    }

    func testDetectsEnvStylePasswordAssignment() {
        XCTAssertTrue(SensitiveDetector.isSensitive(
            "DB_PASSWORD=hunter22secret", isConcealed: false))
    }

    func testDetectsLuhnValidGroupedCardNumber() {
        // Visa test number: Luhn-valid, 16 digits, human grouping.
        XCTAssertTrue(SensitiveDetector.isSensitive(
            "card on file: 4111 1111 1111 1111", isConcealed: false))
    }

    func testConcealedPasteboardTypeAlwaysSensitive() {
        // org.nspasteboard.ConcealedType wins regardless of content (even short, benign text).
        XCTAssertTrue(SensitiveDetector.isSensitive("hello", isConcealed: true))
    }

    // MARK: - Negatives

    func testPlainProseIsNotSensitive() {
        XCTAssertFalse(SensitiveDetector.isSensitive(
            "Meeting moved to Thursday at three, bring the printed agenda for everyone.",
            isConcealed: false))
    }

    func testProseMentioningPasswordWithoutAssignmentIsNotSensitive() {
        XCTAssertFalse(SensitiveDetector.isSensitive(
            "remember to change your password tomorrow", isConcealed: false))
    }

    func testThirteenDigitNonLuhnNumberIsNotSensitive() {
        // 1234567890123: Luhn checksum 55, not divisible by 10.
        XCTAssertFalse(SensitiveDetector.isSensitive("1234567890123", isConcealed: false))
    }

    func testSixteenDigitOrderNumberFailingLuhnIsNotSensitive() {
        // 1234567890123456: Luhn checksum 64, not a valid card number.
        XCTAssertFalse(SensitiveDetector.isSensitive(
            "order number 1234567890123456 shipped", isConcealed: false))
    }

    func testShortTextUnderEightCharactersIsNotSensitive() {
        // Length gate runs before any pattern matching — even a secret-looking prefix passes.
        XCTAssertFalse(SensitiveDetector.isSensitive("sk-1", isConcealed: false))
    }
}
