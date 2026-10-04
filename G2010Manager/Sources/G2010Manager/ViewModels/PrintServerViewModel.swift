import SwiftUI

/// MVVM Pattern: ViewModel for PrintServerPanel
@Observable
public final class PrintServerViewModel {
    public let appState: AppState
    
    public var isStarting: Bool = false
    public var isStopping: Bool = false
    public var isRestarting: Bool = false
    public var isReinstalling: Bool = false
    
    public var serviceInfo: String = ""
    public var isInfoExpanded: Bool = false
    public var manifestText: String? = nil
    public var isManifestExpanded: Bool = false
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    @MainActor
    public func start() async {
        guard !isStarting && appState.serverStatus != .running else { return } // Balking
        isStarting = true
        defer { isStarting = false }
        
        await appState.perform("Start print server") {
            try await appState.printServer.restart()
        }
    }
    
    @MainActor
    public func stop() async {
        guard !isStopping && appState.serverStatus == .running else { return } // Balking
        isStopping = true
        defer { isStopping = false }
        
        await appState.perform("Stop print server") {
            try await appState.printServer.stop()
        }
    }
    
    @MainActor
    public func restart() async {
        guard !isRestarting else { return } // Balking
        isRestarting = true
        defer { isRestarting = false }
        
        await appState.perform("Restart print server") {
            try await appState.printServer.restart()
        }
    }
    
    @MainActor
    public func reinstallQueue() async {
        guard !isReinstalling else { return } // Balking
        isReinstalling = true
        defer { isReinstalling = false }
        
        await appState.perform("Reinstall queue") {
            try await appState.cupsService.ensureQueue(force: true)
        }
    }
    
    @MainActor
    public func loadServiceInfo() async {
        serviceInfo = await appState.printServer.serviceInfo()
    }
    
    @MainActor
    public func loadManifest() {
        manifestText = appState.container.runtimeManager.readInstalledManifest()
    }
}
