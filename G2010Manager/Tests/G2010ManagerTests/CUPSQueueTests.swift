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
}
