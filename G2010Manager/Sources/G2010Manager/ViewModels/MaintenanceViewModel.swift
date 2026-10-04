import SwiftUI

/// MVVM Pattern: ViewModel for MaintenancePanel
@Observable
public final class MaintenanceViewModel {
    public let appState: AppState
    
    public var showingAlert: Bool = false
    public var alertTitle: String = ""
    public var alertMessage: String = ""
    public var isRunning: Bool = false
    public var confirmingDeepClean: Bool = false
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    /// State Pattern: Computes maintenance availability from domain state
    public var availability: MaintenanceAvailability {
        if appState.serverStatus != .running {
            return .serverNotRunning
        }
        if !appState.queueEnabled {
            return .queueUnavailable
        }
        if !appState.activeJobs.isEmpty {
            return .busyWithJobs(count: appState.activeJobs.count)
        }
        return .available
    }
    
    @MainActor
    public func executeCommand(_ command: PrinterCommand) async {
        guard availability.isAvailable && !isRunning else { return } // Balking Pattern
        isRunning = true
        defer { isRunning = false }
        
        do {
            try await command.execute()
            alertTitle = "Success"
            alertMessage = "\(command.name) completed successfully."
            showingAlert = true
        } catch {
            alertTitle = "Error"
            alertMessage = "\(command.name) failed: \(error.localizedDescription)"
            showingAlert = true
        }
    }
    
    @MainActor
    public func standardCleaning() async {
        let command = StandardCleaningCommand(service: appState.maintenanceService)
        await executeCommand(command)
    }
    
    @MainActor
    public func deepCleaning() async {
        let command = DeepCleaningCommand(service: appState.maintenanceService)
        await executeCommand(command)
    }
    
    @MainActor
    public func nozzleCheck() async {
        let command = NozzleCheckCommand(service: appState.maintenanceService)
        await executeCommand(command)
    }
    
    @MainActor
    public func printAlignment() async {
        let command = PrintAlignmentCommand(service: appState.maintenanceService)
        await executeCommand(command)
    }
}
