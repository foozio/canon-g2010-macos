import Foundation

/// Adapter Pattern (Structural): Adapts MaintenanceService routines to MaintenanceServiceProtocol.
/// Allows injection, mocking, and command execution across the application.
public struct DefaultMaintenanceService: MaintenanceServiceProtocol {
    public init() {}
    
    public func standardCleaning() async throws {
        try await MaintenanceService.standardCleaning()
    }
    
    public func deepCleaning() async throws {
        try await MaintenanceService.deepCleaning()
    }
    
    public func nozzleCheck() async throws {
        try await MaintenanceService.nozzleCheck()
    }
    
    public func printAlignment() async throws {
        try await MaintenanceService.printAlignment()
    }
}
