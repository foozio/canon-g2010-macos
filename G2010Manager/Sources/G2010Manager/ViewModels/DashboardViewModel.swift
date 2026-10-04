import SwiftUI

/// MVVM Pattern: ViewModel for DashboardPanel
@Observable
public final class DashboardViewModel {
    public let appState: AppState
    public var isRestarting: Bool = false
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    @MainActor
    public func restartServer() async {
        guard !isRestarting else { return } // Balking Pattern
        isRestarting = true
        defer { isRestarting = false }
        
        await appState.perform("Restart") {
            try await appState.printServer.restart()
        }
    }
}
