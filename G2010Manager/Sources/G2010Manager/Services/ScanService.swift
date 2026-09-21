import Foundation

public actor ScanService {
    private(set) var isScanning = false
    private let runtime = RuntimeManager.shared

    /// Scanner device override for sibling models or test rigs.
    private var deviceOverride: String? {
        let value = ProcessInfo.processInfo.environment["G2010_SCANNER_DEVICE"]
        return (value?.isEmpty == false) ? value : nil
    }

    /// Extract the first `pixma:<id>_<serial>` device from `scanimage -L`
    /// output. Static + pure so a future unit-test target (TASK-012) can
    /// cover it without hardware.
    public static func extractPixmaDevice(from listing: String) -> String? {
        let pattern = #"pixma:[0-9A-Fa-f]+_[0-9A-Fa-f]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: listing, range: NSRange(listing.startIndex..., in: listing)),
              let range = Range(match.range, in: listing) else {
            return nil
        }
        return String(listing[range])
    }

    /// Resolve the scanner device: explicit override, else auto-detect via
    /// `scanimage -L`, else the family default (which the backend will
    /// reject clearly if no such device is attached).
    private func resolveDevice() async -> String {
        if let override = deviceOverride {
            return override
        }
        if let listing = try? await ShellExecutor.run(
            scanimageExecutable,
            arguments: ["-L"],
            environment: runtime.scanEnvironment,
            timeout: 15
        ), let found = Self.extractPixmaDevice(from: listing.stdout) {
            return found
        }
        return RuntimeConstants.scannerDevice
    }

    /// Check if a scanner is present (override counts as present; the family
    /// default alone does not — an unplugged printer must read unavailable).
    public func checkAvailable() async -> Bool {
        if deviceOverride != nil {
            return true
        }
        guard let listing = try? await ShellExecutor.run(
            scanimageExecutable,
            arguments: ["-L"],
            environment: runtime.scanEnvironment,
            timeout: 15
        ) else {
            return false
        }
        return Self.extractPixmaDevice(from: listing.stdout) != nil
    }
    
    private var scanimageExecutable: String {
        if FileManager.default.fileExists(atPath: runtime.scanimageURL.path) {
            return runtime.scanimageURL.path
        }
        return "/opt/homebrew/bin/scanimage"
    }
    
    /// Perform a scan with the given settings. Stdout streams straight to the
    /// output file (never through a shell redirect, never buffered in memory);
    /// a nonzero scanimage exit fails the call even if a file was created.
    public func scan(settings: ScanSettings) async throws -> URL {
        isScanning = true
        defer { isScanning = false }
        
        let outputURL = settings.outputFileURL()
        let device = await resolveDevice()
        
        let result = try await ShellExecutor.run(
            scanimageExecutable,
            arguments: [
                "-d", device,
                "--format=\(settings.format.rawValue)",
                "--resolution", String(settings.resolution.rawValue),
                "--mode", settings.colorMode.rawValue,
            ],
            environment: runtime.scanEnvironment,
            timeout: 120,
            outputFile: outputURL
        )
        
        guard result.succeeded else {
            throw ShellError.executionFailed(command: "scanimage", exitCode: result.exitCode, stderr: result.stderr)
        }
        
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw NSError(domain: "G2010Manager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Scan completed but output file was not created."])
        }
        
        return outputURL
    }
}
