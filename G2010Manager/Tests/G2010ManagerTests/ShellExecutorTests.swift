import XCTest
@testable import G2010ManagerCore

/// ShellExecutor behavior incl. the outputFile redirect (TASK-012).
/// Spawns real local processes (/bin/echo, /bin/sleep) — hermetic apart from
/// that: no hardware, no launchd, no network.
final class ShellExecutorTests: XCTestCase {
    func testEchoReturnsStdoutAndZeroExit() async throws {
        let result = try await ShellExecutor.run("/bin/echo", arguments: ["hello", "world"])
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertEqual(result.stdout, "hello world")
    }

    func testNonzeroExitPropagates() async throws {
        let result = try await ShellExecutor.run("/usr/bin/false")
        XCTAssertFalse(result.succeeded)
        XCTAssertNotEqual(result.exitCode, 0)
    }

    func testOutputFileStreamsToDiskWithEmptyStdout() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shell-out-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let result = try await ShellExecutor.run("/bin/echo", arguments: ["disk"], outputFile: url)
        XCTAssertTrue(result.succeeded)
        XCTAssertTrue(result.stdout.isEmpty)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "disk\n")
    }

    func testTimeoutThrowsTimeoutError() async throws {
        do {
            _ = try await ShellExecutor.run("/bin/sleep", arguments: ["30"], timeout: 1)
            XCTFail("expected a timeout error")
        } catch let error as ShellError {
            guard case .timeout = error else {
                XCTFail("wrong ShellError: \(error)")
                return
            }
        }
    }

    /// A child that ignores SIGTERM must still be reaped (SIGKILL escalation)
    /// instead of hanging the continuation forever.
    func testTimeoutEscalatesWhenSIGTERMIgnored() async throws {
        let start = Date()
        do {
            _ = try await ShellExecutor.run(
                "/bin/bash", arguments: ["-c", "trap '' TERM; while :; do sleep 0.2; done"], timeout: 1
            )
            XCTFail("expected a timeout error")
        } catch let error as ShellError {
            guard case .timeout = error else {
                XCTFail("wrong ShellError: \(error)")
                return
            }
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 1 + ShellExecutor.killGracePeriod + 5)
    }
}
