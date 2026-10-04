import SwiftUI
import G2010ManagerCore
import AppKit

struct TroubleshootPanel: View {
    @Bindable var viewModel: TroubleshootViewModel
    
    var body: some View {
        let appState = viewModel.appState
        Form {
            if let msg = viewModel.resultMessage {
                Section {
                    Text(msg)
                        .foregroundColor(viewModel.resultIsError ? .red : .green)
                }
            }
            
            Section("Quick Fix Actions") {
                Button("Clear Stuck Jobs") {
                    Task {
                        await viewModel.clearStuckJobs()
                    }
                }
                .disabled(viewModel.isExecuting)
                
                Button("Reinstall Print Queue") {
                    Task {
                        // Force reinstall queue: CUPSService.ensureQueue(force: true)
                        await viewModel.reinstallQueue()
                    }
                }
                .disabled(viewModel.isExecuting)
                
                Button("Restart Print Server") {
                    Task {
                        await viewModel.restartServer()
                    }
                }
                .disabled(viewModel.isExecuting)
                
                Button("Remove Stale Canon Queues") {
                    Task {
                        await viewModel.removeStaleQueues()
                    }
                }
                .disabled(viewModel.isExecuting)
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
            appState.logService.refreshIfRotated()
        }
    }
}
