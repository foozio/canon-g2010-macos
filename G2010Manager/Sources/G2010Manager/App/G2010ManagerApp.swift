import SwiftUI
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
    @State private var appState = AppState()
    @Environment(\.openWindow) private var openWindow
    
    var body: some Scene {
        MenuBarExtra("G2010 Manager", systemImage: "printer.fill") {
            MenuBarView()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
        
        Window("G2010 Manager", id: "main") {
            DashboardView()
                .environment(appState)
                .task {
                    appState.startPolling()
                    appState.logService.startTailing()
                }
        }
        .defaultSize(width: 900, height: 600)
    }
}
