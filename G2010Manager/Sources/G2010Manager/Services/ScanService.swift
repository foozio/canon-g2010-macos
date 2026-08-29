import Foundation

actor ScanService {
    private(set) var isScanning = false
    private let scannerDevice = "pixma:04A9183A_0C7A8F"
    private let runtime = RuntimeManager.shared
    
    private var scanimageExecutable: String {
        if FileManager.default.fileExists(atPath: runtime.scanimageURL.path) {
            return runtime.scanimageURL.path
        }
        return "/opt/homebrew/bin/scanimage"
    }
    
    /// Check if scanner is available
    func checkAvailable() async -> Bool {
        guard let result = try? await ShellExecutor.run(
            bash: "\"\(scanimageExecutable)\" -L",
            environment: runtime.scanEnvironment,
            timeout: 15
        ) else {
            return false
        }
        return result.stdout.contains(scannerDevice)
    }
    
    /// Perform a scan with the given settings
    func scan(settings: ScanSettings) async throws -> URL {
        isScanning = true
        defer { isScanning = false }
        
        let outputURL = settings.outputFileURL()
        let command = "\"\(scanimageExecutable)\" -d \"\(scannerDevice)\" --format=\(settings.format.rawValue) --resolution \(settings.resolution.rawValue) --mode \"\(settings.colorMode.rawValue)\" > \"\(outputURL.path)\""
        
        _ = try await ShellExecutor.run(
            bash: command,
            environment: runtime.scanEnvironment,
            timeout: 120
        )
        
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw NSError(domain: "G2010Manager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Scan completed but output file was not created."])
        }
        
        return outputURL
    }
}
