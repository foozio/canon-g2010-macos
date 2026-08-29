import Foundation

struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    
    var succeeded: Bool { exitCode == 0 }
}

enum ShellError: LocalizedError {
    case timeout(command: String)
    case executionFailed(command: String, exitCode: Int32, stderr: String)
    
    var errorDescription: String? {
        switch self {
        case .timeout(let command):
            return "Command timed out: \(command)"
        case .executionFailed(let command, let exitCode, let stderr):
            return "Command failed (exit code \(exitCode)): \(command)\nError: \(stderr)"
        }
    }
}

enum ShellExecutor {
    /// Thread-safe flag for timeout tracking
    private final class TimeoutFlag: @unchecked Sendable {
        private var _value: Bool = false
        private let lock = NSLock()
        
        var value: Bool {
            get { lock.lock(); defer { lock.unlock() }; return _value }
            set { lock.lock(); _value = newValue; lock.unlock() }
        }
    }
    
    /// Run an executable with arguments
    static func run(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 30
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
                process.standardOutput = outPipe
                process.standardError = errPipe
                
                do {
                    try process.run()
                    
                    let timedOut = TimeoutFlag()
                    let commandStr = "\(executable) \(arguments.joined(separator: " "))"
                    
                    // Schedule timeout on the same queue
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                        if process.isRunning {
                            timedOut.value = true
                            process.terminate()
                        }
                    }
                    
                    process.waitUntilExit()
                    
                    if timedOut.value {
                        continuation.resume(throwing: ShellError.timeout(command: commandStr))
                        return
                    }
                    
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let stdout = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let stderr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    
                    let result = ShellResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
                    continuation.resume(returning: result)
                    
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Run a bash command string
    static func run(
        bash command: String,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 30
    ) async throws -> ShellResult {
        return try await run("/bin/bash", arguments: ["-c", command], environment: environment, timeout: timeout)
    }
}
