import XCTest
@testable import G2010ManagerCore

/// lpstat parsing incl. malformed lines (TASK-012, future home of TASK-015).
/// Pure and hermetic — no processes spawned.
final class CUPSParseTests: XCTestCase {
    func testParsesNormalLines() {
        let out = """
            G2010IPP-42 foozio 1024 Mon 21 Sep 2026 10:00:00
            G2010IPP-43 bob 2048 Mon 21 Sep 2026 10:05:00
            """
        let jobs = CUPSService.parseJobs(from: out)
        XCTAssertEqual(jobs.count, 2)
        XCTAssertEqual(jobs[0].id, "G2010IPP-42")
        XCTAssertEqual(jobs[0].owner, "foozio")
        XCTAssertEqual(jobs[0].size, "1024")
        XCTAssertNotNil(jobs[0].submittedAt)
        let cal = Calendar(identifier: .gregorian)
        let parts = cal.dateComponents([.year, .month, .day], from: jobs[0].submittedAt!)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 9)
        XCTAssertEqual(parts.day, 21)
    }

    func testKeepsRowWithUnparseableDate() {
        let jobs = CUPSService.parseJobs(from: "G2010IPP-7 alice 512 someday eventually\n")
        XCTAssertEqual(jobs.count, 1)
        XCTAssertNil(jobs[0].submittedAt)
    }

    func testAbsorbsMultiWordTitlesIntoDateAndKeepsRow() {
        let jobs = CUPSService.parseJobs(from: "G2010IPP-7 alice 512 My Doc Title Here\n")
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs[0].id, "G2010IPP-7")
        XCTAssertNil(jobs[0].submittedAt)
    }

    func testSalvagesShortRowsBestEffort() {
        let jobs = CUPSService.parseJobs(from: "G2010IPP-1 bob\nG2010IPP-2 bob 1 Mon 21 Sep 2026 10:00:00\n")
        XCTAssertEqual(jobs.count, 2)
        XCTAssertEqual(jobs[0].id, "G2010IPP-1")
        XCTAssertEqual(jobs[0].owner, "")
        XCTAssertNil(jobs[0].size)
        XCTAssertNil(jobs[0].submittedAt)
        XCTAssertEqual(jobs[1].id, "G2010IPP-2")
    }

    func testParsesRealMacOSColumnarFormat() {
        // Verbatim shape from `lpstat -W completed -o` (padded columns,
        // space-padded day): previously parsed id/owner/size but never the date.
        let jobs = CUPSService.parseJobs(from: "G2010IPP-45             foozio         1114112   Wed Sep  2 20:35:46 2026\n")
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs[0].id, "G2010IPP-45")
        XCTAssertEqual(jobs[0].owner, "foozio")
        XCTAssertEqual(jobs[0].size, "1114112")
        let cal = Calendar(identifier: .gregorian)
        let parts = cal.dateComponents([.year, .month, .day, .hour, .minute], from: jobs[0].submittedAt!)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 9)
        XCTAssertEqual(parts.day, 2)
        XCTAssertEqual(parts.hour, 20)
        XCTAssertEqual(parts.minute, 35)
    }

    func testKeepsCJKTitleRow() {
        let jobs = CUPSService.parseJobs(from: "G2010IPP-8 chen 256 报告 打印\n")
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs[0].id, "G2010IPP-8")
    }

    func testNeverDropsGarbageLine() {
        let jobs = CUPSService.parseJobs(from: "weird-line-with-no-spaces\n")
        XCTAssertEqual(jobs.count, 1)
        XCTAssertEqual(jobs[0].id, "weird-line-with-no-spaces")
    }

    func testEmptyOutputYieldsNoJobs() {
        XCTAssertTrue(CUPSService.parseJobs(from: "").isEmpty)
        XCTAssertTrue(CUPSService.parseJobs(from: "\n").isEmpty)
    }
}
