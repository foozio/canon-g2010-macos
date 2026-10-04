import SwiftUI

/// Facade Pattern (Structural / eleev/swift-design-patterns)
/// High-level application coordinator managing background polling, state propagation,
/// and mutation error routing.
@Observable
public final class AppState {
    // State
    public var serverStatus: ServerStatus = .unknown
    public var queueState: QueueState = .unknown
    public var activeJobs: [PrintJob] = []
    public var scannerAvailable: Bool = false
    public var isRefreshing: Bool = false
    public var lastRefresh: Date? = nil
    public var errorMessage: String? = nil
    public var isInitialized: Bool = false
    
    // Backwards-compatible computed properties for views/tests
    public var queueEnabled: Bool {
        get { queueState.enabled }
        set { queueState = QueueState(enabled: newValue, status: queueState.status) }
    }
    public var queueStatus: String {
        get { queueState.status }
        set { queueState = QueueState(enabled: queueState.enabled, status: newValue) }
    }
    
    // Dependency Injection Container
    public let container: DependencyContainer
    
    // Service references (Protocols)
    public var printServer: PrintServerServiceProtocol { container.printServerService }
    public var scanService: ScanServiceProtocol { container.scanService }
    public var logService: LogServiceProtocol { container.logService }
    public var cupsService: CUPSServiceProtocol { container.cupsService }
    public var maintenanceService: MaintenanceServiceProtocol { container.maintenanceService }

    public init(container: DependencyContainer = .shared) {
        self.container = container
    }
    
    private var pollingTask: Task<Void, Never>?
    
    /// Initialize runtime and start background polling + the shared log tail.
    /// Idempotent / Balking pattern: called at app launch and window task.
    @MainActor
    public func startPolling() {
        if !isInitialized {
            do {
                try container.runtimeManager.ensureInstalled()
                isInitialized = true
            } catch {
                errorMessage = "Runtime install failed: \(error.localizedDescription)"
            }
        }
        logService.refreshIfRotated()
        
        // Balking Pattern: Guard against concurrent polling tasks
        if let pollingTask, !pollingTask.isCancelled { return }
        pollingTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }
    
    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
    
    /// Refresh all state across services concurrently
    @MainActor
    public func refresh() async {
        isRefreshing = true
        defer {
            isRefreshing = false
            lastRefresh = Date()
        }
        
        serverStatus = await printServer.checkHealth()
        logService.refreshIfRotated()
        
        if let qs = try? await cupsService.getQueueStatus() {
            queueState = QueueState(enabled: qs.enabled, status: qs.status)
        }
        
        activeJobs = (try? await cupsService.listJobs()) ?? []
        scannerAvailable = await scanService.checkAvailable()
    }

    /// Execute a PrinterCommand (Command Pattern) and refresh state
    @MainActor
    public func execute(_ command: PrinterCommand) async {
        await perform(command.name) {
            try await command.execute()
        }
    }

    /// Run a user-initiated mutation, refresh afterwards, and route failure to errorMessage
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
