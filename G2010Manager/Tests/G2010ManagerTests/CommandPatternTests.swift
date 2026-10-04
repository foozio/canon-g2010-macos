import XCTest
@testable import G2010ManagerCore

final class MockCUPSService: CUPSServiceProtocol {
    var canceledJobs: [String] = []
    var canceledAllCalled = false
    var ensureQueueCalled = false
    var removeStaleCalled = false
    
    func listJobs() async throws -> [PrintJob] { [] }
    func cancelJob(id: String) async throws { canceledJobs.append(id) }
    func cancelAll() async throws { canceledAllCalled = true }
    func getQueueStatus() async throws -> (enabled: Bool, status: String) { (true, "idle") }
    func ensureQueue(force: Bool) async throws { ensureQueueCalled = true }
    func removeStaleQueues() async throws { removeStaleCalled = true }
}

final class CommandPatternTests: XCTestCase {
    func testMaintenanceCommandsExecuteUnderlyingService() async throws {
        let mock = MockMaintenanceService()
        
        let standardCmd = StandardCleaningCommand(service: mock)
        XCTAssertEqual(standardCmd.name, "Standard Cleaning")
        try await standardCmd.execute()
        XCTAssertTrue(mock.standardCleaningCalled)
        
        let deepCmd = DeepCleaningCommand(service: mock)
        XCTAssertEqual(deepCmd.name, "Deep Cleaning")
        try await deepCmd.execute()
        XCTAssertTrue(mock.deepCleaningCalled)
        
        let nozzleCmd = NozzleCheckCommand(service: mock)
        XCTAssertEqual(nozzleCmd.name, "Nozzle Check")
        try await nozzleCmd.execute()
        XCTAssertTrue(mock.nozzleCheckCalled)
        
        let alignCmd = PrintAlignmentCommand(service: mock)
        XCTAssertEqual(alignCmd.name, "Print Alignment")
        try await alignCmd.execute()
        XCTAssertTrue(mock.printAlignmentCalled)
    }
    
    func testTroubleshootCommandsExecuteUnderlyingServices() async throws {
        let mockCUPS = MockCUPSService()
        
        let clearCmd = ClearStuckJobsCommand(cups: mockCUPS)
        try await clearCmd.execute()
        XCTAssertTrue(mockCUPS.canceledAllCalled)
        
        let reinstallCmd = ReinstallQueueCommand(cups: mockCUPS)
        try await reinstallCmd.execute()
        XCTAssertTrue(mockCUPS.ensureQueueCalled)
        
        let removeStaleCmd = RemoveStaleQueuesCommand(cups: mockCUPS)
        try await removeStaleCmd.execute()
        XCTAssertTrue(mockCUPS.removeStaleCalled)
    }
    
    func testJobCommandsExecuteCorrectTargets() async throws {
        let mockCUPS = MockCUPSService()
        
        let singleCmd = CancelJobCommand(jobID: "G2010IPP-12", cups: mockCUPS)
        try await singleCmd.execute()
        XCTAssertEqual(mockCUPS.canceledJobs, ["G2010IPP-12"])
        
        let multiCmd = CancelJobsCommand(jobIDs: ["G2010IPP-20", "G2010IPP-15"], cups: mockCUPS)
        try await multiCmd.execute()
        XCTAssertEqual(mockCUPS.canceledJobs, ["G2010IPP-12", "G2010IPP-15", "G2010IPP-20"])
    }
}
