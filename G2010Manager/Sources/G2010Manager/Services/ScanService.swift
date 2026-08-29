import Foundation

actor ScanService {
    private(set) var isScanning = false
    private let scannerDevice = "pixma:04A9183A_0C7A8F"
    private let scanimagePath = "/opt/homebrew/bin/scanimage"
    
    /// Check if scanner is available
    func checkAvailable() async -> Bool {
        guard let result = try? await ShellExecutor.run(bash: "\(scanimagePath) -L", environment: nil, timeout: 15) else {
            return false
        }
        return result.stdout.contains(scannerDevice)
    }
    
    /// Perform a scan with the given settings
    func scan(settings: ScanSettings) async throws -> URL {
        isScanning = true
        defer { isScanning = false }
        
        let outputURL = settings.outputFileURL()
        let command = "\(scanimagePath) -d \"\(scannerDevice)\" --format=\(settings.format.rawValue) --resolution \(settings.resolution.rawValue) --mode \"\(settings.colorMode.rawValue)\" > \"\(outputURL.path)\""
        
        _ = try await ShellExecutor.run(bash: command, environment: nil, timeout: 120) // Scans can take a while
        return outputURL
    }
}
