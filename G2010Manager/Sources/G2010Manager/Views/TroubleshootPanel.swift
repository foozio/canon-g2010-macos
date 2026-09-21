import SwiftUI
import G2010ManagerCore
import AppKit

struct TroubleshootPanel: View {
    @Environment(AppState.self) private var appState
    @State private var resultMessage: String?
    @State private var resultIsError = false
    
    var body: some View {
        Form {
            if let msg = resultMessage {
                Section {
                    Text(msg)
                        .foregroundColor(resultIsError ? .red : .green)
                }
            }
            
            Section("Quick Fix Actions") {
                Button("Clear Stuck Jobs") {
                    Task {
                        await runFix("Cleared stuck jobs.") {
                            try await CUPSService.cancelAll()
                        }
                    }
                }
                Button("Reinstall Print Queue") {
                    Task {
                        await runFix("Reinstalled print queue.") {
                            try await CUPSService.ensureQueue()
                        }
                        await appState.refresh()
                    }
                }
                Button("Restart Print Server") {
                    Task {
                        await runFix("Restarted print server.") {
                            try await appState.printServer.restart()
                        }
                        await appState.refresh()
                    }
                }
                Button("Remove Stale Canon Queues") {
                    Task {
                        await runFix("Removed stale queues.") {
                            try await CUPSService.removeStaleQueues()
                        }
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

    /// Run a quick fix and report its real outcome (TASK-010): green only on
    /// success, red with the error on failure — never unconditional success.
    private func runFix(_ successMessage: String, _ action: () async throws -> Void) async {
        do {
            try await action()
            resultMessage = successMessage
            resultIsError = false
        } catch {
            resultMessage = "Failed: \(error.localizedDescription)"
            resultIsError = true
        }
    }
}
