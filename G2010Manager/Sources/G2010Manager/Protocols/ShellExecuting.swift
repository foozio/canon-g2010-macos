import Foundation

/// Protocol abstraction for shell execution (Adapter / Dependency Inversion Pattern).
/// Decouples services from direct Foundation Process calls to enable isolated unit testing.
public protocol ShellExecuting: Sendable {
    func run(
        _ executable: String,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        outputFile: URL?
    ) async throws -> ShellResult
}

extension ShellExecuting {
    public func run(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 30,
        outputFile: URL? = nil
    ) async throws -> ShellResult {
        try await run(
            executable,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            outputFile: outputFile
        )
    }
}
