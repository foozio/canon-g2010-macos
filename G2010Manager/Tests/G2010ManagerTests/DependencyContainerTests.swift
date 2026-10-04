import XCTest
@testable import G2010ManagerCore

final class MockShellExecutor: ShellExecuting {
    var executedCommands: [String] = []
    var stubbedResult = ShellResult(stdout: "", stderr: "", exitCode: 0)
    
    func run(
        _ executable: String,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        outputFile: URL?
    ) async throws -> ShellResult {
        executedCommands.append(executable)
        return stubbedResult
    }
}

final class MockMaintenanceService: MaintenanceServiceProtocol {
    var standardCleaningCalled = false
    var deepCleaningCalled = false
    var nozzleCheckCalled = false
    var printAlignmentCalled = false
    var shouldThrow = false
    
    func standardCleaning() async throws {
        if shouldThrow { throw NSError(domain: "test", code: 1, userInfo: nil) }
        standardCleaningCalled = true
    }
    
    func deepCleaning() async throws {
        if shouldThrow { throw NSError(domain: "test", code: 2, userInfo: nil) }
        deepCleaningCalled = true
    }
    
    func nozzleCheck() async throws {
        if shouldThrow { throw NSError(domain: "test", code: 3, userInfo: nil) }
        nozzleCheckCalled = true
    }
    
    func printAlignment() async throws {
        if shouldThrow { throw NSError(domain: "test", code: 4, userInfo: nil) }
        printAlignmentCalled = true
    }
}

final class DependencyContainerTests: XCTestCase {
    func testLiveContainerResolvesAllServices() {
        let container = DependencyContainer.live()
        XCTAssertNotNil(container.shellExecutor)
        XCTAssertNotNil(container.runtimeManager)
        XCTAssertNotNil(container.printServerService)
        XCTAssertNotNil(container.cupsService)
        XCTAssertNotNil(container.scanService)
        XCTAssertNotNil(container.maintenanceService)
        XCTAssertNotNil(container.logService)
    }
    
    func testAppStateUsesInjectedContainer() {
        let mockShell = MockShellExecutor()
        let mockMaintenance = MockMaintenanceService()
        let runtime = RuntimeManager.shared
        let printServer = PrintServerService(runtime: runtime, shell: mockShell)
        let cups = DefaultCUPSService()
        let scan = ScanService(runtime: runtime, shell: mockShell)
        let log = LogService()
        
        let customContainer = DependencyContainer(
            shellExecutor: mockShell,
            runtimeManager: runtime,
            printServerService: printServer,
            cupsService: cups,
            scanService: scan,
            maintenanceService: mockMaintenance,
            logService: log
        )
        
        let appState = AppState(container: customContainer)
        XCTAssertIdentical(appState.container, customContainer)
    }
}
