import XCTest
@testable import G2010ManagerCore

/// pixma device extraction from `scanimage -L` output (TASK-012).
/// Pure and hermetic — the discovery core without hardware.
final class PixmaExtractTests: XCTestCase {
    func testExtractsFirstDevice() {
        let listing = """
            device `pixma:04A9183A_0C7A8F' is a Canon PIXMA G2010 Series flatbed scanner
            device `pixma:04A9183B_112233' is a Canon PIXMA G3010 Series flatbed scanner
            """
        XCTAssertEqual(
            ScanService.extractPixmaDevice(from: listing),
            "pixma:04A9183A_0C7A8F"
        )
    }

    func testReturnsNilWithoutMatch() {
        XCTAssertNil(ScanService.extractPixmaDevice(from: "No scanners were identified.\n"))
        XCTAssertNil(ScanService.extractPixmaDevice(from: ""))
    }

    func testMatchesLowercaseHex() {
        XCTAssertEqual(
            ScanService.extractPixmaDevice(from: "device `pixma:04a9183a_0c7a8f' is a scanner"),
            "pixma:04a9183a_0c7a8f"
        )
    }
}
