import Foundation

/// Command Pattern (Gang of Four / eleev/swift-design-patterns)
/// Encapsulates an operational task or hardware action into an executable command object.
public protocol PrinterCommand: Sendable {
    var name: String { get }
    func execute() async throws
}
