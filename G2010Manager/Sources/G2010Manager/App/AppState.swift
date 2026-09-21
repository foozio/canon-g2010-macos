import SwiftUI

@Observable
public final class AppState {
    // State
    public var serverStatus: ServerStatus = .unknown
    public var queueEnabled: Bool = false
    public var queueStatus: String = "Unknown"
    public var activeJobs: [PrintJob] = []
    public var scannerAvailable: Bool = false
    public var isRefreshing: Bool = false
    public var lastRefresh: Date? = nil
    public var errorMessage: String? = nil
    public var isInitialized: Bool = false
    
    // Services
    public let printServer = PrintServerService()
    public let scanService = ScanService()
    public let logService = LogService()

    public init() {}
    
    private var pollingTask: Task<Void, Never>?
    
    /// Initialize runtime and start background polling
    public func startPolling() {
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
    
    public func stopPolling() { pollingTask?.cancel() }
    
    /// Refresh all state
    @MainActor
    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false; lastRefresh = Date() }
        
        serverStatus = await printServer.checkHealth()
        logService.refreshIfRotated()
        
        if let qs = try? await CUPSService.getQueueStatus() {
            queueEnabled = qs.enabled
            queueStatus = qs.status
        }
        
        activeJobs = (try? await CUPSService.listJobs()) ?? []
        scannerAvailable = await scanService.checkAvailable()
    }

    /// Run a user-initiated mutation, refresh afterwards, and route any
    /// failure to errorMessage (rendered by ErrorBanner). Background refresh
    /// reads keep using try? — this path is for mutations only (TASK-010).
    @MainActor
    public func perform(_ label: String, _ action: () async throws -> Void) async {
        errorMessage = nil
        do {
            try await action()
        } catch {
            errorMessage = "\(label) failed: \(error.localizedDescription)"
        }
        await refresh()
    }
}
