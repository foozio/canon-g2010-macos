import XCTest
@testable import G2010ManagerCore

/// Queue-reinstall decision table (TASK-012, locks TASK-015): only a
/// missing, mismatched, or paused queue justifies losing in-flight jobs.
final class CUPSQueueTests: XCTestCase {
    func testHealthyQueueNeedsNoRecreate() {
        XCTAssertFalse(CUPSService.needsRecreate(queueExists: true, uriMatches: true, enabled: true))
    }

    func testMissingQueueRecreates() {
        XCTAssertTrue(CUPSService.needsRecreate(queueExists: false, uriMatches: true, enabled: true))
        XCTAssertTrue(CUPSService.needsRecreate(queueExists: false, uriMatches: false, enabled: false))
    }

    func testMismatchedURIrecreates() {
        XCTAssertTrue(CUPSService.needsRecreate(queueExists: true, uriMatches: false, enabled: true))
    }

    func testPausedQueueRecreates() {
        XCTAssertTrue(CUPSService.needsRecreate(queueExists: true, uriMatches: true, enabled: false))
    }

    func testAnyUnhealthyCombinationRecreates() {
        XCTAssertTrue(CUPSService.needsRecreate(queueExists: true, uriMatches: false, enabled: false))
        XCTAssertTrue(CUPSService.needsRecreate(queueExists: false, uriMatches: true, enabled: false))
        XCTAssertTrue(CUPSService.needsRecreate(queueExists: false, uriMatches: false, enabled: true))
    }

    // MARK: - parseQueueEnabled (lpstat -p phrasing)

    func testIdleQueueIsEnabled() {
        XCTAssertTrue(CUPSService.parseQueueEnabled(
            "printer G2010IPP is idle.  enabled since Sat Oct  4 13:00:00 2026"))
    }

    /// macOS says "now printing", not "is printing" — a busy queue must not
    /// read as disabled (that recreated the queue and dropped in-flight jobs).
    func testNowPrintingQueueIsEnabled() {
        XCTAssertTrue(CUPSService.parseQueueEnabled(
            "printer G2010IPP now printing G2010IPP-42.  enabled since Sat Oct  4 13:00:00 2026"))
    }

    func testIsPrintingQueueIsEnabled() {
        XCTAssertTrue(CUPSService.parseQueueEnabled("printer G2010IPP is printing G2010IPP-7."))
    }

    func testEnabledSinceAloneIsEnabled() {
        XCTAssertTrue(CUPSService.parseQueueEnabled(
            "printer G2010IPP is waiting.  enabled since Sat Oct  4 13:00:00 2026"))
    }

    func testDisabledQueueIsDisabled() {
        XCTAssertFalse(CUPSService.parseQueueEnabled(
            "printer G2010IPP disabled since Sat Oct  4 13:00:00 2026 -\n\tPaused"))
    }

    func testReasonLineDoesNotFlipEnabledQueue() {
        XCTAssertTrue(CUPSService.parseQueueEnabled(
            "printer G2010IPP is idle.  enabled since Sat Oct  4 13:00:00 2026\n\tfilter disabled by admin earlier"))
    }

    func testFailedLpstatIsDisabled() {
        XCTAssertFalse(CUPSService.parseQueueEnabled(
            "printer G2010IPP is idle.  enabled since Sat Oct  4 13:00:00 2026", succeeded: false))
        XCTAssertFalse(CUPSService.parseQueueEnabled(""))
    }
}
