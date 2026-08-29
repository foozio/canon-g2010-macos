import Foundation

enum MaintenanceService {
    private static let deviceURI = "usb://Canon/G2010%20series?serial=0C7A8F"
    private static let usbBackend = "/usr/libexec/cups/backend/usb"
    
    /// Standard head cleaning
    static func standardCleaning() async throws {
        let command = "CLEANING=1"
        try await sendBJLCommand(command)
    }
    
    /// Deep head cleaning (uses more ink)
    static func deepCleaning() async throws {
        let command = "CLEANING=2"
        try await sendBJLCommand(command)
    }
    
    /// Print nozzle check pattern
    static func nozzleCheck() async throws {
        let command = "NOZZLECHECK=1"
        try await sendBJLCommand(command)
    }
    
    /// Auto print head alignment
    static func printAlignment() async throws {
        let command = "ALIGNMENT=1"
        try await sendBJLCommand(command)
    }
    
    /// Internal: send a BJL command string to the printer
    private static func sendBJLCommand(_ command: String) async throws {
        // The BJL command format is:
        // ESC [K \x02 \x00 \x00 \x1b (pipe) BJL command \x0a \x1b (pipe)
        // Send via: printf "<escaped_bytes>" | DEVICE_URI=<uri> <usbBackend>
        
        let bjlString = "\\033[K\\002\\000\\000\\033|\(command)\\n\\033|"
        let bashCommand = "printf \"\(bjlString)\" | DEVICE_URI=\"\(deviceURI)\" \(usbBackend)"
        
        _ = try await ShellExecutor.run(bash: bashCommand, environment: nil, timeout: 15)
    }
}
