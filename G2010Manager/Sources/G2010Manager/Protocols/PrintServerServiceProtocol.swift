import Foundation

/// Protocol abstraction for print server lifecycle and health monitoring.
public protocol PrintServerServiceProtocol: Sendable {
    func checkHealth() async -> ServerStatus
    func restart() async throws
    func stop() async throws
    func serviceInfo() async -> String
}
