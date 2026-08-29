import Foundation
import Network

actor PrintServerService {
    private let runtime = RuntimeManager.shared
    
    /// Thread-safe flag for connection state callbacks
    private final class CompletionFlag: @unchecked Sendable {
        private var _value: Bool = false
        private let lock = NSLock()
        
        var value: Bool {
            get { lock.lock(); defer { lock.unlock() }; return _value }
            set { lock.lock(); _value = newValue; lock.unlock() }
        }
    }
    
    /// Check if port 8632 is listening using Network.framework NWConnection
    func checkHealth() async -> ServerStatus {
        let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: runtime.port)!, using: .tcp)
        
        return await withCheckedContinuation { continuation in
            let completed = CompletionFlag()
            connection.stateUpdateHandler = { state in
                guard !completed.value else { return }
                switch state {
                case .ready:
                    completed.value = true
                    connection.cancel()
                    continuation.resume(returning: .running)
                case .failed, .cancelled:
                    completed.value = true
                    continuation.resume(returning: .stopped)
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout after 3 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                guard !completed.value else { return }
                completed.value = true
                connection.cancel()
                continuation.resume(returning: .stopped)
            }
        }
    }
    
    /// Restart and bootstrap the print server service
    func restart() async throws {
        // 1. Ensure runtime files and LaunchAgent plist are updated
        try runtime.ensureInstalled()
        
        // 2. Unload existing launchd job
        _ = try? await ShellExecutor.run(bash: "launchctl bootout gui/\(uid)/\(runtime.agentLabel)", timeout: 10)
        _ = try? await ShellExecutor.run(bash: "pkill -f ippeveprinter", timeout: 10)
        
        // Brief pause for port cleanup
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // 3. Bootstrap and kickstart the LaunchAgent
        _ = try await ShellExecutor.run(bash: "launchctl bootstrap gui/\(uid) '\(runtime.launchAgentPlistURL.path)'", timeout: 10)
        _ = try await ShellExecutor.run(bash: "launchctl kickstart -k gui/\(uid)/\(runtime.agentLabel)", timeout: 10)
        
        // 4. Poll until the server responds on port 8632 (up to 15s)
        var isRunning = false
        for _ in 0..<15 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if await checkHealth() == .running {
                isRunning = true
                break
            }
        }
        
        if !isRunning {
            throw NSError(domain: "G2010Manager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Print server failed to start on port \(runtime.port). Check logs."])
        }
        
        // 5. Ensure system CUPS queue is registered
        try? await CUPSService.ensureQueue()
    }
    
    /// Stop the print server service
    func stop() async throws {
        _ = try? await ShellExecutor.run(bash: "launchctl bootout gui/\(uid)/\(runtime.agentLabel)", timeout: 10)
        _ = try? await ShellExecutor.run(bash: "pkill -f ippeveprinter", timeout: 10)
    }
    
    /// Get launchd service info
    func getServiceInfo() async throws -> String {
        let result = try await ShellExecutor.run(bash: "launchctl print gui/\(uid)/\(runtime.agentLabel)", timeout: 10)
        return result.stdout
    }
    
    /// Get current UID
    private var uid: uid_t { getuid() }
}
