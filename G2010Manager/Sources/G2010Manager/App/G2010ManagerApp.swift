import SwiftUI
import G2010ManagerCore
import AppKit

/// Forces the SPM executable to be treated as a proper macOS GUI application.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory = menu bar icon visible, no Dock icon
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@main
struct G2010ManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var appState: AppState
    @State private var coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    init() {
        let state = AppState()
        let coord = AppCoordinator()
        _appState = State(initialValue: state)
        _coordinator = State(initialValue: coord)
        
        // Start polling + the shared log tail at launch, not on the main
        // Window's .task: a menu-bar-only session never opens the window,
        // and the MenuBarExtra content only exists while its panel is open.
        Task { @MainActor in state.startPolling() }
    }
    
    var body: some Scene {
        MenuBarExtra("G2010 Manager", systemImage: "printer.fill") {
            MenuBarView()
                .environment(appState)
                .environment(coordinator)
                .task { appState.startPolling() }  // idempotent
        }
        .menuBarExtraStyle(.window)
        
        Window("G2010 Manager", id: "main") {
            DashboardView()
                .environment(appState)
                .environment(coordinator)
                .task { appState.startPolling() }  // idempotent
        }
        .defaultSize(width: 900, height: 600)
    }
}
