import Foundation

/// Protocol abstraction for printer maintenance and BJL command routines.
public protocol MaintenanceServiceProtocol: Sendable {
    func standardCleaning() async throws
    func deepCleaning() async throws
    func nozzleCheck() async throws
    func printAlignment() async throws
}
