import SwiftUI

/// MVVM Pattern: ViewModel for ScanPanel
@Observable
public final class ScanViewModel {
    public let appState: AppState
    
    public var resolution: ScanResolution = .dpi300
    public var colorMode: ScanColorMode = .color
    public var format: ScanFormat = .png
    public var destinationURL: URL = ScanSettings.defaultDestination
    
    public var isScanning: Bool = false
    public var lastScanURL: URL?
    public var scanError: String?
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    @MainActor
    public func startScan() async {
        guard !isScanning && appState.scannerAvailable else { return } // Balking
        isScanning = true
        scanError = nil
        defer { isScanning = false }
        
        let settings = ScanSettings(
            resolution: resolution,
            colorMode: colorMode,
            format: format,
            destinationURL: destinationURL
        )
        
        do {
            let outputURL = try await appState.scanService.scan(settings: settings)
            lastScanURL = outputURL
        } catch {
            scanError = error.localizedDescription
        }
    }
    
    public func setDestination(url: URL) {
        self.destinationURL = url
    }
}
