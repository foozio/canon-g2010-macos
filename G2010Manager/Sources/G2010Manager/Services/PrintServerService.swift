import Foundation
import Network

public actor PrintServerService: PrintServerServiceProtocol {
    private let runtime: RuntimeManaging
    private let shell: ShellExecuting
    
    public init(runtime: RuntimeManaging = RuntimeManager.shared, shell: ShellExecuting = DefaultShellExecutor()) {
        self.runtime = runtime
        self.shell = shell
    }
    
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
    public func checkHealth() async -> ServerStatus {
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
    
    /// Environment mapping the controller's PRINTSERVER_* knobs onto this
    /// install (TASK-004). *_SOURCE point at the pristine mirror so the GUI
    /// and the .command recovery path execute one tested implementation; the
    /// plist source is the already-substituted installed plist (the controller
    /// skips the copy when source and destination coincide).
    private var controllerEnvironment: [String: String] {
        let source = runtime.installedSourceDirURL
        return [
            "PRINTSERVER_LABEL": runtime.agentLabel,
            "PRINTSERVER_PORT": String(runtime.port),
            "PRINTSERVER_PLIST_SOURCE": runtime.launchAgentPlistURL.path,
            "PRINTSERVER_PLIST_DEST": runtime.launchAgentPlistURL.path,
            "PRINTSERVER_LOG": runtime.serverLogURL.path,
            "PRINTSERVER_RUNTIME_DIR": runtime.appSupportDir.path,
            "PRINTSERVER_START_SOURCE": source.appendingPathComponent("start-printserver.sh").path,
            "PRINTSERVER_PIPELINE_SOURCE": source.appendingPathComponent("print-pipeline.sh").path,
            "PRINTSERVER_PPD_SOURCE": source.appendingPathComponent("stp-bjc-G2000-series.5.3.ppd").path,
        ]
    }

    /// Run the lifecycle controller (argv-form, never shell-string) and throw
    /// its stderr on failure so the GUI can surface it instead of swallowing.
    private func runController(_ command: String, timeout: TimeInterval) async throws {
        let result = try await shell.run(
            runtime.controllerURL.path,
            arguments: [command],
            environment: controllerEnvironment,
            timeout: timeout
        )
        guard result.succeeded else {
            throw ShellError.executionFailed(command: "printserver-control.sh \(command)", exitCode: result.exitCode, stderr: result.stderr)
        }
    }

    /// Restart via the tested controller: single-owner reinstall, guarded
    /// orphan kill, bootstrap, readiness wait with bind-scope warning.
    public func restart() async throws {
        // 1. Ensure runtime files (incl. the pristine source mirror) exist.
        try runtime.ensureInstalled()

        // 2. The controller owns the lifecycle from here (bootout →
        //    guarded kill → reinstall → bootstrap → kickstart → wait).
        try await runController("restart", timeout: 90)

        // 3. Ensure system CUPS queue is registered. Non-force (converge) on
        //    purpose: automatic restarts must not wipe in-flight jobs — only
        //    the explicit "Reinstall Queue" actions pass force: true. Errors
        //    propagate so the GUI's errorMessage shows them (the server itself
        //    is already up at this point).
        do {
            try await CUPSService.ensureQueue()
        } catch {
            throw NSError(domain: "G2010Manager", code: 20, userInfo: [
                NSLocalizedDescriptionKey: "Print server started, but registering the CUPS queue failed: \(error.localizedDescription)"
            ])
        }
    }

    /// Stop via the tested controller (bootout + guarded orphan kill only).
    public func stop() async throws {
        try await runController("stop", timeout: 30)
    }
    
    /// Get launchd service info
    public func getServiceInfo() async throws -> String {
        let result = try await shell.run("/bin/launchctl", arguments: ["print", "gui/\(uid)/\(runtime.agentLabel)"], timeout: 10)
        return result.stdout
    }
    
    /// Service info conforming to PrintServerServiceProtocol
    public func serviceInfo() async -> String {
        (try? await getServiceInfo()) ?? ""
    }
    
    /// Get current UID
    private var uid: uid_t { getuid() }
}
