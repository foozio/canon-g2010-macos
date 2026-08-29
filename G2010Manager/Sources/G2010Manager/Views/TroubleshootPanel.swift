import SwiftUI
import AppKit

struct TroubleshootPanel: View {
    @Environment(AppState.self) private var appState
    @State private var resultMessage: String?
    
    var body: some View {
        Form {
            if let msg = resultMessage {
                Section {
                    Text(msg)
                        .foregroundColor(.green)
                }
            }
            
            Section("Quick Fix Actions") {
                Button("Clear Stuck Jobs & Reset USB") {
                    Task {
                        try? await CUPSService.cancelAll()
                        resultMessage = "Cleared stuck jobs."
                    }
                }
                Button("Reinstall Print Queue") {
                    Task {
                        try? await CUPSService.ensureQueue()
                        resultMessage = "Reinstalled print queue."
                        await appState.refresh()
                    }
                }
                Button("Restart Print Server") {
                    Task {
                        try? await appState.printServer.restart()
                        resultMessage = "Restarted print server."
                        await appState.refresh()
                    }
                }
                Button("Remove Stale Canon Queues") {
                    Task {
                        try? await CUPSService.removeStaleQueues()
                        resultMessage = "Removed stale queues."
                        await appState.refresh()
                    }
                }
            }
            
            Section("Server Log") {
                LogConsoleView(logLines: .init(
                    get: { appState.logService.logLines },
                    set: { _ in }
                ))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Troubleshoot")
        .toolbar {
            ToolbarItem {
                Button("Clear") {
                    appState.logService.clearBuffer()
                }
            }
            ToolbarItem {
                Button("Copy Log") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(appState.logService.fullLogText, forType: .string)
                }
            }
            ToolbarItem {
                Button("Open in Console") {
                    let url = URL(fileURLWithPath: appState.logService.logFilePath)
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .onAppear {
            appState.logService.startTailing()
        }
        .onDisappear {
            appState.logService.stopTailing()
        }
    }
}
