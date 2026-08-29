import SwiftUI

@Observable
final class AppState {
    // State
    var serverStatus: ServerStatus = .unknown
    var queueEnabled: Bool = false
    var queueStatus: String = "Unknown"
    var activeJobs: [PrintJob] = []
    var scannerAvailable: Bool = false
    var isRefreshing: Bool = false
    var lastRefresh: Date? = nil
    var errorMessage: String? = nil
    var isInitialized: Bool = false
    
    // Services
    let printServer = PrintServerService()
    let scanService = ScanService()
    let logService = LogService()
    
    private var pollingTask: Task<Void, Never>?
    
    /// Initialize runtime and start background polling
    func startPolling() {
        if !isInitialized {
            try? RuntimeManager.shared.ensureInstalled()
            isInitialized = true
        }
        
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }
    
    func stopPolling() { pollingTask?.cancel() }
    
    /// Refresh all state
    @MainActor
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false; lastRefresh = Date() }
        
        serverStatus = await printServer.checkHealth()
        
        if let qs = try? await CUPSService.getQueueStatus() {
            queueEnabled = qs.enabled
            queueStatus = qs.status
        }
        
        activeJobs = (try? await CUPSService.listJobs()) ?? []
        scannerAvailable = await scanService.checkAvailable()
    }
}
