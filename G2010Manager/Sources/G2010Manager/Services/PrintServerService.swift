import Foundation
import Network

actor PrintServerService {
    private let repoPath = "/Users/foozio/Downloads/Codes/g2010i"
    private let agentLabel = "com.foozio.g2010.printserver"
    private let port: UInt16 = 8632
    
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
        let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
        
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
    
    /// Restart via printserver-control.sh
    func restart() async throws {
        let scriptPath = "\(repoPath)/harness/printserver-control.sh"
        _ = try await ShellExecutor.run(bash: "bash '\(scriptPath)' restart", timeout: 30)
    }
    
    /// Stop the server
    func stop() async throws {
        _ = try? await ShellExecutor.run(bash: "launchctl bootout gui/\(uid)/\(agentLabel)", timeout: 10)
        _ = try? await ShellExecutor.run(bash: "pkill -f ippeveprinter", timeout: 10)
    }
    
    /// Get launchd service info
    func getServiceInfo() async throws -> String {
        let result = try await ShellExecutor.run(bash: "launchctl print gui/\(uid)/\(agentLabel)", timeout: 10)
        return result.stdout
    }
    
    /// Get current UID
    private var uid: uid_t { getuid() }
}
