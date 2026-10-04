import XCTest
@testable import G2010ManagerCore

/// RuntimeConstants single-source coherence (TASK-012, locks TASK-011):
/// every derived identity embeds the one serial / port it claims to.
final class RuntimeConstantsTests: XCTestCase {
    func testPortAndQueueAreSane() {
        XCTAssertEqual(RuntimeConstants.ippPort, 8632)
        XCTAssertFalse(RuntimeConstants.queueName.isEmpty)
        XCTAssertTrue(RuntimeConstants.agentLabel.hasPrefix("com."))
    }

    func testDerivedIdentitiesEmbedTheirSources() {
        XCTAssertTrue(RuntimeConstants.ippURI.contains(String(RuntimeConstants.ippPort)))
        XCTAssertTrue(RuntimeConstants.deviceURI.contains(RuntimeConstants.printerSerial))
        XCTAssertTrue(RuntimeConstants.scannerDevice.contains(RuntimeConstants.printerSerial))
    }

    func testRuntimeManagerAgreesWithConstants() {
        XCTAssertEqual(RuntimeManager.shared.agentLabel, RuntimeConstants.agentLabel)
        XCTAssertEqual(RuntimeManager.shared.port, RuntimeConstants.ippPort)
        XCTAssertEqual(
            RuntimeManager.shared.launchAgentPlistURL.lastPathComponent,
            "\(RuntimeConstants.agentLabel).plist"
        )
    }

    func testVersionConstantsAreSane() {
        XCTAssertFalse(RuntimeConstants.appVersion.isEmpty)
        XCTAssertFalse(RuntimeConstants.buildVersion.isEmpty)
        XCTAssertTrue(RuntimeConstants.displayVersion.contains("."))
        XCTAssertTrue(RuntimeConstants.fullVersionString.contains(RuntimeConstants.displayVersion))
    }
}
