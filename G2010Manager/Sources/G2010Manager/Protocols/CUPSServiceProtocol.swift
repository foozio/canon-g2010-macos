import Foundation

/// Protocol abstraction for CUPS queue and job administration.
public protocol CUPSServiceProtocol: Sendable {
    func listJobs() async throws -> [PrintJob]
    func cancelJob(id: String) async throws
    func cancelAll() async throws
    func getQueueStatus() async throws -> (enabled: Bool, status: String)
    func ensureQueue(force: Bool) async throws
    func removeStaleQueues() async throws
}
