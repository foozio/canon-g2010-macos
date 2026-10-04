import SwiftUI

/// MVVM Pattern: ViewModel for MenuBarView
@Observable
public final class MenuBarViewModel {
    public let appState: AppState
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    @MainActor
    public func toggleServer() async {
        if appState.serverStatus == .running {
            await appState.perform("Stop print server") {
                try await appState.printServer.stop()
            }
        } else {
            await appState.perform("Start print server") {
                try await appState.printServer.restart()
            }
        }
    }
}
