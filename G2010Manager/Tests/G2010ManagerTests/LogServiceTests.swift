import XCTest
@testable import G2010ManagerCore

/// Log tail rotation survival (TASK-012, locks TASK-014). Hermetic: a temp
/// log file stands in for the server log; no daemon involved.
final class LogServiceTests: XCTestCase {
    private func makeLog(with content: String) throws -> (dir: URL, log: URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let log = dir.appendingPathComponent("test.log")
        FileManager.default.createFile(atPath: log.path, contents: content.data(using: .utf8))
        return (dir, log)
    }

    func testTailSurvivesRotation() throws {
        let (dir, log) = try makeLog(with: "line1\n")
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = LogService(logFilePath: log.path)
        defer { service.stopTailing() }
        service.startTailing()
        XCTAssertTrue(service.logLines.contains("line1"))

        // Rotate exactly like the controller does: move aside, recreate, write.
        try FileManager.default.moveItem(at: log, to: dir.appendingPathComponent("test.log.1"))
        FileManager.default.createFile(atPath: log.path, contents: "line2\n".data(using: .utf8))
        service.refreshIfRotated()

        // Reopen reads existing content synchronously; pump briefly in case
        // event delivery races the test thread.
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertTrue(service.logLines.contains("line2"))
    }

    func testDoubleStartKeepsLines() throws {
        let (dir, log) = try makeLog(with: "line1\n")
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = LogService(logFilePath: log.path)
        defer { service.stopTailing() }
        service.startTailing()
        service.startTailing()
        XCTAssertTrue(service.logLines.contains("line1"))
    }

    func testMissingFileStartsNothing() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let service = LogService(logFilePath: dir.appendingPathComponent("absent.log").path)
        defer { service.stopTailing() }
        service.startTailing()
        XCTAssertTrue(service.logLines.isEmpty)
        // A later-appearing file is picked up via the refresh hook.
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        FileManager.default.createFile(
            atPath: dir.appendingPathComponent("absent.log").path,
            contents: "late\n".data(using: .utf8)
        )
        service.refreshIfRotated()
        XCTAssertTrue(service.logLines.contains("late"))
    }
}
