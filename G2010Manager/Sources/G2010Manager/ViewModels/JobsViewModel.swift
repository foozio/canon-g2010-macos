import SwiftUI

/// MVVM Pattern: ViewModel for JobsPanel
@Observable
public final class JobsViewModel {
    public let appState: AppState
    public var selection: Set<PrintJob.ID> = []
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    @MainActor
    public func cancelSelected() async {
        let targets = selection.sorted()
        guard !targets.isEmpty else { return }
        
        let command = CancelJobsCommand(jobIDs: targets, cups: appState.cupsService)
        await appState.execute(command)
        selection.subtract(targets)
    }
    
    @MainActor
    public func cancelJob(id: String) async {
        let command = CancelJobCommand(jobID: id, cups: appState.cupsService)
        await appState.execute(command)
        selection.remove(id)
    }
    
    @MainActor
    public func cancelAll() async {
        let command = ClearStuckJobsCommand(cups: appState.cupsService)
        await appState.execute(command)
        selection.removeAll()
    }
    
    @MainActor
    public func refresh() async {
        await appState.refresh()
    }
}
