import XCTest
@testable import G2010ManagerCore

final class MaintenanceViewModelTests: XCTestCase {
    func testAvailabilityStateMachine() {
        let appState = AppState()
        let vm = MaintenanceViewModel(appState: appState)
        
        // 1. Initial / server stopped
        appState.serverStatus = .stopped
        XCTAssertEqual(vm.availability, .serverNotRunning)
        XCTAssertFalse(vm.availability.isAvailable)
        XCTAssertEqual(vm.availability.reasonMessage, "Print server is not running.")
        
        // 2. Server running, but queue disabled
        appState.serverStatus = .running
        appState.queueEnabled = false
        XCTAssertEqual(vm.availability, .queueUnavailable)
        XCTAssertFalse(vm.availability.isAvailable)
        XCTAssertEqual(vm.availability.reasonMessage, "Print queue is unavailable.")
        
        // 3. Server running, queue enabled, but busy with active jobs
        appState.queueEnabled = true
        appState.activeJobs = [
            PrintJob(id: "1", name: "Doc", status: "pending", owner: "user", size: "10k", submittedAt: nil)
        ]
        XCTAssertEqual(vm.availability, .busyWithJobs(count: 1))
        XCTAssertFalse(vm.availability.isAvailable)
        XCTAssertEqual(vm.availability.reasonMessage, "Wait for 1 active job(s) to finish — maintenance must not interrupt printing.")
        
        // 4. Server running, queue enabled, no active jobs -> Available
        appState.activeJobs = []
        XCTAssertEqual(vm.availability, .available)
        XCTAssertTrue(vm.availability.isAvailable)
        XCTAssertNil(vm.availability.reasonMessage)
    }
}
