import Foundation

/// Protocol abstraction for scanner detection and acquisition.
public protocol ScanServiceProtocol: Sendable {
    var isScanning: Bool { get async }
    func checkAvailable() async -> Bool
    func scan(settings: ScanSettings) async throws -> URL
}
