import XCTest
@testable import G2010ManagerCore

/// ScanSettings output naming (TASK-012): timestamped, per-format, in the
/// chosen destination. Pure and hermetic.
final class ScanSettingsTests: XCTestCase {
    func testOutputFileURLUsesSettings() {
        let dir = FileManager.default.temporaryDirectory
        let settings = ScanSettings(
            resolution: .dpi300, colorMode: .color,
            format: .png, destinationURL: dir
        )
        let url = settings.outputFileURL()
        XCTAssertEqual(url.deletingLastPathComponent().path, dir.path)
        XCTAssertTrue(url.lastPathComponent.hasPrefix("Scan_"))
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".png"))
    }

    func testOutputFileURLHonorsEveryFormat() {
        for format in ScanFormat.allCases {
            let url = ScanSettings(format: format).outputFileURL()
            XCTAssertTrue(
                url.lastPathComponent.hasSuffix(".\(format.fileExtension)"),
                "wrong extension for \(format)"
            )
        }
    }

    func testOutputFileURLTimestampShape() {
        let name = ScanSettings().outputFileURL().lastPathComponent
        let pattern = #"^Scan_\d{4}-\d{2}-\d{2}_\d{6}\.png$"#
        XCTAssertNotNil(
            name.range(of: pattern, options: .regularExpression),
            "unexpected filename shape: \(name)"
        )
    }

    func testDefaultDestinationIsPictures() {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        XCTAssertEqual(ScanSettings().destinationURL, pictures)
        XCTAssertEqual(ScanSettings.defaultDestination, pictures)
    }
}
