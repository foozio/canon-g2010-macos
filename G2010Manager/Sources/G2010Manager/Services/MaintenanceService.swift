import Foundation

public enum MaintenanceService {
    /// Printer device URI: overridable for sibling models or test rigs
    /// (PRINTSERVER_DEVICE_URI is the shell-pipeline counterpart).
    private static var deviceURI: String {
        if let override = ProcessInfo.processInfo.environment["G2010_DEVICE_URI"], !override.isEmpty {
            return override
        }
        return RuntimeConstants.deviceURI
    }

    /// Apple USB backend used as the BJL transport. Overridable for testing
    /// (mirrors the G2010_REPO_ROOT seam): point it at /usr/bin/false to prove
    /// the failure path, /usr/bin/true for the success path.
    private static var usbBackend: String {
        if let override = ProcessInfo.processInfo.environment["G2010_USB_BACKEND"], !override.isEmpty {
            return override
        }
        return "/usr/libexec/cups/backend/usb"
    }
    
    /// Standard head cleaning
    public static func standardCleaning() async throws {
        let command = "CLEANING=1"
        try await sendBJLCommand(command)
    }
    
    /// Deep head cleaning (uses more ink)
    public static func deepCleaning() async throws {
        let command = "CLEANING=2"
        try await sendBJLCommand(command)
    }
    
    /// Print nozzle check pattern
    public static func nozzleCheck() async throws {
        let command = "NOZZLECHECK=1"
        try await sendBJLCommand(command)
    }
    
    /// Auto print head alignment
    public static func printAlignment() async throws {
        let command = "ALIGNMENT=1"
        try await sendBJLCommand(command)
    }
    
    /// Internal: send a BJL command string to the printer
    ///
    /// The backend's exit code is the only signal we have — a nonzero exit
    /// (device absent, I/O error, rejected command) throws so the UI reports
    /// an Error alert instead of a false "Success". Note this proves the
    /// backend *accepted* the bytes, not that the firmware acted on them
    /// (mechanical effect on VER:1.040 is unverified — see docs/03).
    private static func sendBJLCommand(_ command: String) async throws {
        // The BJL command format is:
        // ESC [K \x02 \x00 \x00 \x1b (pipe) BJL command \x0a \x1b (pipe)
        // Send via: printf "<escaped_bytes>" | DEVICE_URI=<uri> <usbBackend>
        
        let bjlString = "\\033[K\\002\\000\\000\\033|\(command)\\n\\033|"
        let bashCommand = "printf \"\(bjlString)\" | DEVICE_URI=\"\(deviceURI)\" \(usbBackend)"
        
        let result = try await ShellExecutor.run(bash: bashCommand, environment: nil, timeout: 15)
        guard result.succeeded else {
            throw ShellError.executionFailed(command: "usb backend BJL \(command)", exitCode: result.exitCode, stderr: result.stderr)
        }
    }
}
