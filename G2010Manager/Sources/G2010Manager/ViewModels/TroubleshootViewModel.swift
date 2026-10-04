import SwiftUI

/// MVVM Pattern: ViewModel for TroubleshootPanel
@Observable
public final class TroubleshootViewModel {
    public let appState: AppState
    
    public var resultMessage: String?
    public var resultIsError: Bool = false
    public var isExecuting: Bool = false
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    @MainActor
    public func executeCommand(_ command: PrinterCommand) async {
        guard !isExecuting else { return } // Balking Pattern
        isExecuting = true
        defer { isExecuting = false }
        
        do {
            try await command.execute()
            resultMessage = "\(command.name) completed."
            resultIsError = false
        } catch {
            resultMessage = "\(command.name) failed: \(error.localizedDescription)"
            resultIsError = true
        }
        await appState.refresh()
    }
    
    @MainActor
    public func clearStuckJobs() async {
        let command = ClearStuckJobsCommand(cups: appState.cupsService)
        await executeCommand(command)
    }
    
    @MainActor
    public func reinstallQueue() async {
        let command = ReinstallQueueCommand(cups: appState.cupsService)
        await executeCommand(command)
    }
    
    @MainActor
    public func restartServer() async {
        let command = RestartServerCommand(printServer: appState.printServer)
        await executeCommand(command)
    }
    
    @MainActor
    public func removeStaleQueues() async {
        let command = RemoveStaleQueuesCommand(cups: appState.cupsService)
        await executeCommand(command)
    }
}
