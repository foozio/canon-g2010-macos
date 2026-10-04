import Foundation

public struct ShellResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32
    
    public var succeeded: Bool { exitCode == 0 }
}

public enum ShellError: LocalizedError {
    case timeout(command: String)
    case executionFailed(command: String, exitCode: Int32, stderr: String)
    
    public var errorDescription: String? {
        switch self {
        case .timeout(let command):
            return "Command timed out: \(command)"
        case .executionFailed(let command, let exitCode, let stderr):
            return "Command failed (exit code \(exitCode)): \(command)\nError: \(stderr)"
        }
    }
}

public enum ShellExecutor {
    /// Seconds between SIGTERM and SIGKILL when a command times out.
    static let killGracePeriod: TimeInterval = 2

    /// Thread-safe flag for timeout tracking
    private final class TimeoutFlag: @unchecked Sendable {
        private var _value: Bool = false
        private let lock = NSLock()
        
        var value: Bool {
            get { lock.lock(); defer { lock.unlock() }; return _value }
            set { lock.lock(); _value = newValue; lock.unlock() }
        }
    }
    
    /// Run an executable with arguments.
    ///
    /// Prefer this argv-form over the bash-string overload whenever no shell operator is
    /// needed — arguments are passed without shell parsing, so dynamic values
    /// (job IDs, UIDs, paths) cannot inject. When `outputFile` is set, stdout
    /// streams straight to disk (large outputs are never buffered in memory)
    /// and `result.stdout` is empty; stderr is still captured.
    public static func run(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 30,
        outputFile: URL? = nil
    ) async throws -> ShellResult {
        return try await withCheckedThrowingContinuation { continuation in
            let queue = DispatchQueue(label: "com.g2010manager.shell", qos: .userInitiated)
            queue.async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                
                if let environment = environment {
                    var currentEnv = ProcessInfo.processInfo.environment
                    for (key, value) in environment {
                        currentEnv[key] = value
                    }
                    process.environment = currentEnv
                }
                
                let outPipe = Pipe()
                let errPipe = Pipe()
                var outHandle: FileHandle? = nil
                if let outputFile = outputFile {
                    FileManager.default.createFile(atPath: outputFile.path, contents: nil)
                    guard let handle = FileHandle(forWritingAtPath: outputFile.path) else {
                        continuation.resume(throwing: ShellError.executionFailed(command: executable, exitCode: -1, stderr: "cannot open output file \(outputFile.path)"))
                        return
                    }
                    outHandle = handle
                    process.standardOutput = handle
                } else {
                    process.standardOutput = outPipe
                }
                process.standardError = errPipe
                
                do {
                    try process.run()
                    
                    let timedOut = TimeoutFlag()
                    var commandStr = "\(executable) \(arguments.joined(separator: " "))"
                    if let outputFile = outputFile {
                        commandStr += " > \(outputFile.path)"
                    }
                    
                    // Schedule timeout on the same queue
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                        if process.isRunning {
                            timedOut.value = true
                            process.terminate()
                            // SIGTERM can be ignored/trapped; escalate so
                            // waitUntilExit() below cannot hang forever.
                            let pid = process.processIdentifier
                            DispatchQueue.global().asyncAfter(deadline: .now() + killGracePeriod) {
                                if process.isRunning {
                                    kill(pid, SIGKILL)
                                }
                            }
                        }
                    }
                    
                    process.waitUntilExit()
                    outHandle?.closeFile()
                    
                    if timedOut.value {
                        continuation.resume(throwing: ShellError.timeout(command: commandStr))
                        return
                    }
                    
                    let stdout: String
                    if outputFile != nil {
                        stdout = ""
                    } else {
                        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                        stdout = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    }
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let stderr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    
                    let result = ShellResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
                    continuation.resume(returning: result)
                    
                } catch {
                    outHandle?.closeFile()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Run a bash command string
    public static func run(
        bash command: String,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 30
    ) async throws -> ShellResult {
        return try await run("/bin/bash", arguments: ["-c", command], environment: environment, timeout: timeout)
    }
}

/// Default implementation of ShellExecuting adapting ShellExecutor
public struct DefaultShellExecutor: ShellExecuting {
    public init() {}
    
    public func run(
        _ executable: String,
        arguments: [String],
        environment: [String: String]?,
        timeout: TimeInterval,
        outputFile: URL?
    ) async throws -> ShellResult {
        try await ShellExecutor.run(
            executable,
            arguments: arguments,
            environment: environment,
            timeout: timeout,
            outputFile: outputFile
        )
    }
}

