import Foundation

/// Protocol abstraction for log monitoring and tailing.
public protocol LogServiceProtocol: AnyObject, Sendable {
    var logLines: [String] { get }
    var logFilePath: String { get }
    var fullLogText: String { get }
    func startTailing()
    func stopTailing()
    func refreshIfRotated()
    func clearBuffer()
}
