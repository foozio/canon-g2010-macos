import Foundation

/// Adapter Pattern (Structural): Adapts CUPSService routines to CUPSServiceProtocol.
/// Allows injection, mocking, and decoupling in ViewModels and AppState.
public struct DefaultCUPSService: CUPSServiceProtocol {
    public init() {}
    
    public func listJobs() async throws -> [PrintJob] {
        try await CUPSService.listJobs()
    }
    
    public func cancelJob(id: String) async throws {
        try await CUPSService.cancelJob(id: id)
    }
    
    public func cancelAll() async throws {
        try await CUPSService.cancelAll()
    }
    
    public func getQueueStatus() async throws -> (enabled: Bool, status: String) {
        try await CUPSService.getQueueStatus()
    }
    
    public func ensureQueue(force: Bool) async throws {
        try await CUPSService.ensureQueue(force: force)
    }
    
    public func removeStaleQueues() async throws {
        try await CUPSService.removeStaleQueues()
    }
}
